#include <assert.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>
#include <errno.h>

#include <driver/gpio.h>
#include <esp32/rom/ets_sys.h>
#include <esp_log.h>
#include <esp_system.h>
#include <esp_timer.h>
#include <esp_types.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/queue.h>
#include <freertos/task.h>
#include <nvs.h>
#include <nvs_flash.h>

#include <borneo/system.h>
#include "pump.h"

#define PUMP_TIMER_GROUP TIMER_GROUP_1
#define PUMP_TIMER_INDEX 0

typedef struct {
    const char* name;
    uint8_t io_pin;
} pump_port_t;

typedef struct {
    volatile pump_state_t state; // pump state
    volatile int duration; // in ms
    esp_timer_handle_t timer;
} channel_status_t;

typedef struct {
    channel_status_t channels[CONFIG_PUMP_CHANNEL_COUNT];
} pumps_context_t;

static int start_timer();
static int setup_for_duration(size_t ch, int64_t duration);
static int setup_for_volume(size_t ch, uint32_t vol);
static void timer_callback(void* params);
static int save_settings();
static int load_settings();

static const uint8_t PUMP_PORT_TABLE[CONFIG_PUMP_CHANNEL_COUNT] = {

#if CONFIG_PUMP_CH0_ENABLED
    CONFIG_PUMP_CH0_GPIO,
#endif // CONFIG_PUMP_CH2_ENABLED

#if CONFIG_PUMP_CH1_ENABLED
    CONFIG_PUMP_CH1_GPIO,
#endif // CONFIG_PUMP_CH2_ENABLED

#if CONFIG_PUMP_CH2_ENABLED
    CONFIG_PUMP_CH2_GPIO,
#endif // CONFIG_PUMP_CH2_ENABLED

#if CONFIG_PUMP_CH3_ENABLED
    CONFIG_PUMP_CH3_GPIO,
#endif // CONFIG_PUMP_CH3_ENABLED

#if CONFIG_PUMP_CH4_ENABLED
    CONFIG_PUMP_CH4_GPIO,
#endif // CONFIG_PUMP_CH4_ENABLED

#if CONFIG_PUMP_CH5_ENABLED
    CONFIG_PUMP_CH5_GPIO,
#endif // CONFIG_PUMP_CH5_ENABLED

};

static pump_device_settings_t _settings = { 0 };
static pumps_context_t _ctx = { 0 };

static const char* TAG = "pump";

static const char* NVS_NAMESPACE = "pump";
static const char* NVS_PUMP_CONFIG_KEY = "config";

int pump_init()
{
    uint64_t pins_mask = 0ULL;
    for (size_t i = 0; i < CONFIG_PUMP_CHANNEL_COUNT; i++) {
        pins_mask |= (1ULL << (uint64_t)PUMP_PORT_TABLE[i]);
    }

    gpio_config_t io_conf = { 0 };
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = pins_mask;
    io_conf.pull_down_en = 1;
    io_conf.pull_up_en = 0;
    BO_TRY(gpio_config(&io_conf));

    for (size_t i = 0; i < CONFIG_PUMP_CHANNEL_COUNT; i++) {
        // Turn off all
        BO_TRY(pump_off(i));

        // Initialize the timer
        channel_status_t* channel = &_ctx.channels[i];
        esp_timer_create_args_t timer_args;
        timer_args.callback = &timer_callback;
        timer_args.arg = (void*)i;
        timer_args.name = NULL;
        BO_MUST(esp_timer_create(&timer_args, &channel->timer));
    }

    // Load the settings
    int rc = load_settings();
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        ESP_LOGI(TAG, "There was no settings, using the default settings...");
        BO_TRY(save_settings());
    }
    else if (rc) {
        return rc;
    }
    return 0;
}

int pump_volume(size_t ch, uint32_t vol)
{
    if (ch >= CONFIG_PUMP_CHANNEL_COUNT || vol == 0) {
        return -EINVAL;
    }
    BO_TRY(setup_for_volume(ch, vol));
    BO_TRY(start_timer());
    return 0;
}

int pump_duration(size_t ch, int64_t duration)
{
    if (ch >= CONFIG_PUMP_CHANNEL_COUNT || duration <= 0) {
        return -EINVAL;
    }
    BO_TRY(setup_for_duration(ch, duration));
    BO_TRY(start_timer());
    return 0;
}

int pump_volume_all(const uint32_t* vols)
{
    if (vols == NULL) {
        return -EINVAL;
    }
    for (size_t ch = 0; ch < CONFIG_PUMP_CHANNEL_COUNT; ch++) {
        BO_TRY(setup_for_volume(ch, vols[ch]));
    }
    BO_TRY(start_timer());
    return 0;
}

int pump_on(size_t ch)
{
    if (ch >= CONFIG_PUMP_CHANNEL_COUNT) {
        return -EINVAL;
    }
    if (_ctx.channels[ch].state != PUMP_STATE_IDLE) {
        return -EBUSY;
    }
    BO_TRY(gpio_set_level(PUMP_PORT_TABLE[ch], 1));
    return 0;
}

int pump_off(size_t ch)
{
    if (ch >= CONFIG_PUMP_CHANNEL_COUNT) {
        return -EINVAL;
    }
    BO_TRY(gpio_set_level(PUMP_PORT_TABLE[ch], 0));
    return 0;
}

int pump_update_speed(size_t ch, uint32_t speed)
{
    // TODO thread sync
    if (ch >= CONFIG_PUMP_CHANNEL_COUNT) {
        return -EINVAL;
    }
    _settings.channels[ch].speed = speed;
    return save_settings();
}

int pump_get_speed(size_t ch, uint32_t* speed)
{
    if (speed == NULL || ch >= CONFIG_PUMP_CHANNEL_COUNT) {
        return -EINVAL;
    }
    return _settings.channels[ch].speed;
}

bool pump_is_any_busy()
{
    for (size_t i = 0; i < CONFIG_PUMP_CHANNEL_COUNT; i++) {
        if (_ctx.channels[i].state != PUMP_STATE_IDLE) {
            return true;
        }
    }
    return false;
}

int pump_get_channel_info(size_t ch, pump_channel_status_t* status_out)
{
    if (ch >= CONFIG_PUMP_CHANNEL_COUNT || status_out == NULL) {
        return -EINVAL;
    }
    status_out->state = _ctx.channels[ch].state;
    status_out->speed = _settings.channels[ch].speed;
    return 0;
}

int setup_for_volume(size_t ch, uint32_t vol)
{
    if (ch >= CONFIG_PUMP_CHANNEL_COUNT || vol == 0) {
        return -EINVAL;
    }
    if (_ctx.channels[ch].state != PUMP_STATE_IDLE) {
        return -EBUSY;
    }

    // Calculate the execution duration
    uint32_t speed = _settings.channels[ch].speed;
    int64_t dur = vol / speed;
    if (dur <= 0) {
        return -EINVAL;
    }
    BO_TRY(setup_for_duration(ch, dur));
    return 0;
}

int setup_for_duration(size_t ch, int64_t duration)
{
    if (ch >= CONFIG_PUMP_CHANNEL_COUNT || duration <= 0) {
        return -EINVAL;
    }
    if (_ctx.channels[ch].state != PUMP_STATE_IDLE) {
        return -EBUSY;
    }

    channel_status_t* pc = &_ctx.channels[ch];
    pc->duration = duration;
    pc->state = PUMP_STATE_WAIT;
    return 0;
}

static int start_timer()
{
    for (size_t i = 0; i < CONFIG_PUMP_CHANNEL_COUNT; i++) {
        channel_status_t* pc = &_ctx.channels[i];
        if (pc->state == PUMP_STATE_WAIT) {
            pc->state = PUMP_STATE_BUSY;
            pump_on(i);
            BO_MUST(esp_timer_start_once(pc->timer, (uint64_t)pc->duration * 1000ULL));
        }
    }
    return 0;
}

static void timer_callback(void* params)
{
    size_t ch = (size_t)params;
    channel_status_t* ch_status = &_ctx.channels[ch];
    pump_off(ch);
    ch_status->state = PUMP_STATE_IDLE;
}

static int save_settings()
{
    ESP_LOGI(TAG, "Saving config...");

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) {
        return err;
    }

    err = nvs_set_blob(nvs_handle, NVS_PUMP_CONFIG_KEY, &_settings, sizeof(_settings));
    if (err != ESP_OK) {
        return err;
    }

    err = nvs_commit(nvs_handle);
    if (err != ESP_OK) {
        return err;
    }

    nvs_close(nvs_handle);
    return ESP_OK;
}

static int load_settings()
{
    ESP_LOGI(TAG, "Loading config...");

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) {
        return err;
    }

    size_t size = sizeof(_settings);
    err = nvs_get_blob(nvs_handle, NVS_PUMP_CONFIG_KEY, &_settings, &size);
    if (err != ESP_OK) {
        return err;
    }

    nvs_close(nvs_handle);
    return ESP_OK;
}