#include <string.h>
#include <errno.h>
#include <math.h>

#include <esp_system.h>
#include <esp_event.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <driver/ledc.h>
#include <esp_err.h>
#include <esp_log.h>
#include <nvs_flash.h>
#include <esp_rom_md5.h>

#include <smf/smf.h>

#include <borneo/common.h>
#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>
#include <borneo/algo/astronomy.h>
#include <borneo/wifi.h>

#include "../lyfi-events.h"
#include "../algo.h"
#include "led.h"

static const struct smf_state LED_STATE_TABLE[];

void led_sch_drive(time_t utc_now, led_color_t color);

static void system_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data);
static void led_events_handler(void* handler_args, esp_event_base_t base, int32_t id, void* event_data);

static void led_render_task();

void led_temporary_state_entry();
void led_temporary_state_run();
void led_temporary_state_exit();

static void normal_state_entry();
static void normal_state_run();
static void normal_state_exit();

static void preview_state_entry();
static void preview_state_run();
static void preview_state_exit();

static void dimming_mode_entry();
static void dimming_mode_run();
static void dimming_mode_exit();

#define TAG "lyfi-ledc"

#define SECS_PER_DAY 172800
#define LED_MAX_DUTY ((1 << LEDC_TIMER_12_BIT) - 1)
#define LED_DUTY_RES LEDC_TIMER_10_BIT

static inline led_duty_t channel_brightness_to_duty(led_brightness_t power);
static inline void color_to_duties(const led_color_t color, led_duty_t* duties);
static int led_set_channel_duty(uint8_t ch, led_duty_t duty);
static int led_set_duties(const led_duty_t* duties);

static int led_mode_manual_entry();
static int led_mode_scheduled_entry();
static int led_mode_sun_entry();

ESP_EVENT_DEFINE_BASE(LYFI_LED_EVENTS);
/*
    LED_STATE_NORMAL = 0,
    LED_STATE_DIMMING = 1,
    LED_STATE_TEMPORARY = 2,
    LED_STATE_PREVIEW = 3,

    LED_STATE_COUNT,

    LED_STATE_NORMAL_MANUAL_MODE,
    LED_STATE_NORMAL_SCHEDULED_MODE,
    LED_STATE_NORMAL_SUN_MODE,
    */

static const struct smf_state LED_STATE_TABLE[] = {
    [LED_STATE_NORMAL] = SMF_CREATE_STATE(&normal_state_entry, &normal_state_run, &normal_state_exit, NULL, NULL),

    [LED_STATE_DIMMING] = SMF_CREATE_STATE(&dimming_mode_entry, &dimming_mode_run, &dimming_mode_exit, NULL, NULL),

    [LED_STATE_TEMPORARY]
    = SMF_CREATE_STATE(&led_temporary_state_entry, &led_temporary_state_run, &led_temporary_state_exit, NULL, NULL),

    [LED_STATE_PREVIEW] = SMF_CREATE_STATE(&preview_state_entry, &preview_state_run, &preview_state_exit, NULL, NULL),
};

static const uint8_t LED_GPIOS[CONFIG_LYFI_LED_CHANNEL_COUNT] = {

#if CONFIG_LYFI_LED_CH0_ENABLED
    CONFIG_LYFI_LED_CH0_GPIO,
#endif

#if CONFIG_LYFI_LED_CH1_ENABLED
    CONFIG_LYFI_LED_CH1_GPIO,
#endif

#if CONFIG_LYFI_LED_CH2_ENABLED
    CONFIG_LYFI_LED_CH2_GPIO,
#endif

#if CONFIG_LYFI_LED_CH3_ENABLED
    CONFIG_LYFI_LED_CH3_GPIO,
#endif

#if CONFIG_LYFI_LED_CH4_ENABLED
    CONFIG_LYFI_LED_CH4_GPIO,
#endif

#if CONFIG_LYFI_LED_CH5_ENABLED
    CONFIG_LYFI_LED_CH5_GPIO,
#endif

#if CONFIG_LYFI_LED_CH6_ENABLED
    CONFIG_LYFI_LED_CH6_GPIO,
#endif

#if CONFIG_LYFI_LED_CH7_ENABLED
    CONFIG_LYFI_LED_CH7_GPIO,
#endif

#if CONFIG_LYFI_LED_CH8_ENABLED
    CONFIG_LYFI_LED_CH8_GPIO,
#endif

#if CONFIG_LYFI_LED_CH9_ENABLED
    CONFIG_LYFI_LED_CH9_GPIO,
#endif
};

static const led_color_t LED_COLOR_BLANK = { 0 };

struct led_status _led;

static ledc_channel_config_t _ledc_channels[LYFI_LED_CHANNEL_COUNT];
/**
 * Initialize the LED controller
 *
 */
int led_init()
{
    ESP_LOGI(TAG, "Initializing LED controller....");

    memset(&_led, 0, sizeof(_led));
    memset(_ledc_channels, 0, sizeof(_ledc_channels));

    struct led_factory_settings factory_settings;
    BO_TRY(led_load_factory_settings(&factory_settings));

    BO_TRY(led_load_user_settings());

    ESP_LOGI(TAG, "Initializing PWM timer for LEDC....");

    // Initialize the first timer
    // TODO allow set the freq in product definition
    ledc_timer_config_t ledc_timer = {
        .duty_resolution = LEDC_TIMER_12_BIT,
        .freq_hz = factory_settings.pwm_freq,

#if SOC_LEDC_SUPPORT_HS_MODE
        .speed_mode = LEDC_HIGH_SPEED_MODE,
        .timer_num = LEDC_TIMER_0,
#else
        .speed_mode = LEDC_LOW_SPEED_MODE,
        .timer_num = LEDC_TIMER_1,
#endif
    };

    BO_TRY(ledc_timer_config(&ledc_timer));

    // More than 8 channels need to initialize the second timer
#if LYFI_LED_CHANNEL_COUNT > 8
    ledc_timer.speed_mode = LEDC_LOW_SPEED_MODE;
    ledc_timer.timer_num = LEDC_TIMER_1;
    BO_TRY(ledc_timer_config(&ledc_timer));
#endif

    ESP_LOGI(TAG, "PWM timer initialized.");

    // Initialize all channels
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        _ledc_channels[ch].gpio_num = LED_GPIOS[ch];
        _ledc_channels[ch].intr_type = LEDC_INTR_DISABLE;
        _ledc_channels[ch].hpoint = (ch * LED_MAX_DUTY) / LYFI_LED_CHANNEL_COUNT;
#if SOC_LEDC_SUPPORT_HS_MODE
        if (ch <= 7) { // the next timer
            _ledc_channels[ch].speed_mode = LEDC_HIGH_SPEED_MODE;
            _ledc_channels[ch].timer_sel = LEDC_TIMER_0;
        }
        else {
            _ledc_channels[ch].speed_mode = LEDC_LOW_SPEED_MODE;
            _ledc_channels[ch].timer_sel = LEDC_TIMER_1;
        }
#else
        _ledc_channels[ch].speed_mode = LEDC_LOW_SPEED_MODE;
        _ledc_channels[ch].timer_sel = LEDC_TIMER_1;
#endif
        _ledc_channels[ch].duty = 0;
        _ledc_channels[ch].channel = (uint8_t)ch % 8;
        ESP_LOGI(TAG, "Configure GPIO [%u] as PWM Channel [%u], hpoint=[%u]", _ledc_channels[ch].gpio_num,
                 _ledc_channels[ch].channel, _ledc_channels[ch].hpoint);
        BO_TRY(ledc_channel_config(&_ledc_channels[ch]));
    }

    // Initialize fade service.
    BO_TRY(ledc_fade_func_install(0));

    smf_set_initial(SMF_CTX(&_led), &LED_STATE_TABLE[LED_STATE_NORMAL]);

    BO_TRY(esp_event_handler_register(LYFI_LED_EVENTS, ESP_EVENT_ANY_ID, led_events_handler, NULL));
    BO_TRY(esp_event_handler_register(BO_SYSTEM_EVENTS, ESP_EVENT_ANY_ID, system_events_handler, NULL));

    ESP_LOGI(TAG, "Starting LED controller...");

    if (_led.settings.mode == LED_MODE_SUN) {
        BO_TRY(led_sun_init());
    }

    xTaskCreate(&led_render_task, "led_render_task", 2 * 1024, NULL, tskIDLE_PRIORITY + 2, NULL);
    ESP_LOGI(TAG, "LED Controller module has been initialized successfully.");
    return 0;
}

inline uint8_t led_get_state() { return _led.ctx.current - &LED_STATE_TABLE[0]; }

inline uint8_t led_get_previous_state()
{
    if (_led.ctx.previous == NULL) {
        return LED_STATE_COUNT;
    }
    return _led.ctx.previous - &LED_STATE_TABLE[0];
}

void led_blank()
{
    if (memcmp(_led.color, LED_COLOR_BLANK, sizeof(led_color_t)) != 0) {
        led_update_color(LED_COLOR_BLANK);
    }
}

int led_set_color(const led_color_t color)
{
    if (!(bo_power_is_on() && led_get_state() == LED_STATE_DIMMING)) {
        return -EINVAL;
    }
    // Verify the colors
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        if (color[ch] > LED_BRIGHTNESS_MAX) {
            return -EINVAL;
        }
    }

    switch (_led.settings.mode) {

    case LED_MODE_MANUAL:
        memcpy(_led.settings.manual_color, color, sizeof(led_color_t));
        break;

    case LED_MODE_SUN:
        memcpy(_led.settings.sun_color, color, sizeof(led_color_t));
        break;

    default:
        break;
    }

    BO_TRY(led_update_color(color));

    return 0;
}

int led_get_color(led_color_t color)
{
    memcpy(color, _led.color, sizeof(led_color_t));
    return ESP_OK;
}

led_brightness_t led_get_channel_power(uint8_t ch)
{
    //
    assert(ch < LYFI_LED_CHANNEL_COUNT);
    return _led.color[ch];
}

inline led_duty_t channel_brightness_to_duty(led_brightness_t brightness)
{
    switch (_led.settings.correction_method) {
    case LED_CORRECTION_CIE1931:
        return LED_CORLUT_CIE1931[brightness];

    case LED_CORRECTION_GAMMA:
        return LED_CORLUT_GAMMA[brightness];

    case LED_CORRECTION_LOG:
        return LED_CORLUT_LOG[brightness];

    case LED_CORRECTION_EXP:
        return LED_CORLUT_EXP[brightness];

    default: {
        if (LED_MAX_DUTY == LED_BRIGHTNESS_MAX) {
            return brightness;
        }
        else {
            return (led_duty_t)(((uint32_t)brightness * LED_MAX_DUTY + (LED_BRIGHTNESS_MAX / 2)) / LED_BRIGHTNESS_MAX);
        }
    } break;
    }
}

inline void color_to_duties(const led_color_t color, led_duty_t* duties)
{
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        duties[ch] = channel_brightness_to_duty(color[ch]);
    }
}

int led_set_channel_duty(uint8_t ch, led_duty_t duty)
{
    if (ch >= LYFI_LED_CHANNEL_COUNT || duty > LED_MAX_DUTY) {
        return -1;
    }

    if (ledc_get_duty(_ledc_channels[ch].speed_mode, _ledc_channels[ch].channel) == (uint32_t)duty) {
        return 0;
    }

    uint32_t total_duty = 0;
    for (size_t ich = 0; ich < LYFI_LED_CHANNEL_COUNT; ich++) {
        if (ich == ch) {
            continue;
        }
        total_duty += ledc_get_duty(_ledc_channels[ich].speed_mode, _ledc_channels[ich].channel);
    }

    uint32_t hpoint = total_duty % (1 << LED_DUTY_RES);
    BO_TRY(ledc_set_duty_and_update(_ledc_channels[ch].speed_mode, _ledc_channels[ch].channel, duty, hpoint));
    return 0;
}

int led_get_duties(led_duty_t* duties)
{
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        uint32_t duty = ledc_get_duty(_ledc_channels[ch].speed_mode, _ledc_channels[ch].channel);
        if (duty == LEDC_ERR_DUTY) {
            return -EIO;
        }
        duties[ch] = (led_duty_t)duty;
    }
    return 0;
}

int led_set_duties(const led_duty_t* duties)
{
    uint32_t hpoint = 0;
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        led_duty_t duty = duties[ch];
        BO_MUST(ledc_set_duty_and_update(_ledc_channels[ch].speed_mode, _ledc_channels[ch].channel, duty, hpoint));
        hpoint = (hpoint + duty) % (1 << LED_DUTY_RES);
    }
    return 0;
}

int led_set_channel_brightness(uint8_t ch, led_brightness_t brightness)
{
    if (ch >= LYFI_LED_CHANNEL_COUNT || brightness > LED_BRIGHTNESS_MAX) {
        return -EINVAL;
    }
    led_duty_t duty = channel_brightness_to_duty(brightness);
    BO_TRY(led_set_channel_duty(ch, duty));
    return 0;
}

int led_update_color(const led_color_t color)
{
    if (memcmp(color, _led.color, sizeof(led_color_t)) == 0) {
        return 0;
    }
    memcpy(_led.color, color, sizeof(led_color_t));
    return 0;
}

int led_set_schedule(const struct led_scheduler_item* items, size_t count)
{
    if (items == NULL) {
        return -EINVAL;
    }
    if (count > LYFI_LEDC_SCHEDULER_ITEMS_CAPACITY) {
        return -EINVAL;
    }

    if (count >= 2) {
        // Check the item array is sorted ascending and no duplicates
        for (size_t i = 1; i < count; i++) {
            if (items[i].instant <= items[i - 1].instant) {
                return -EINVAL;
            }
        }
    }

    if (count > 0 && items[count - 1].instant >= SECS_PER_DAY * 2) {
        return -EINVAL;
    }

    if (count > 0) {
        memcpy(_led.settings.scheduler.items, items, sizeof(struct led_scheduler_item) * count);
        _led.settings.scheduler.item_count = count;
    }
    else {
        memset(&_led.settings.scheduler, 0, sizeof(_led.settings.scheduler));
    }

    return 0;
}

const struct led_scheduler* led_get_schedule() { return &_led.settings.scheduler; }

const struct led_user_settings* led_get_settings() { return &_led.settings; }

const struct led_status* led_get_status() { return &_led; }

bool led_is_blank()
{
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        if (_led.color[ch] > 0) {
            return false;
        }
    }
    return true;
}

static void system_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data)
{
    switch (event_id) {
    case BO_EVENT_SHUTDOWN_FAULT:
    case BO_EVENT_FATAL_ERROR: {
        if (led_is_fading()) {
            BO_MUST(led_fade_stop());
        }
        led_blank();
        BO_MUST(led_switch_state(LED_STATE_NORMAL));
    } break;

    case BO_EVENT_SHUTDOWN_SCHEDULED: {
        BO_MUST(led_fade_black());
        BO_MUST(led_switch_state(LED_STATE_NORMAL));
    } break;

    case BO_EVENT_POWER_ON: {
        BO_MUST(led_fade_to_normal());
        BO_MUST(led_switch_state(LED_STATE_NORMAL));
    } break;

    case BO_EVENT_GEO_LOCATION_CHANGED: {
        int rc = led_sun_update_scheduler();
        if (rc) {
            ESP_LOGE(TAG, "Failed to update solar scheduler");
        }
    } break;

    default:
        break;
    }
}

static void led_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data)
{
    switch (event_id) {

    case LYFI_LED_NOTIFY_TEMPORARY_STATE: {
        assert(bo_power_is_on());
        if (led_get_state() == LED_STATE_NORMAL
            && (_led.settings.mode == LED_MODE_SCHEDULED || _led.settings.mode == LED_MODE_SUN)) {
            led_switch_state(LED_STATE_TEMPORARY);
        }
        else if (led_get_state() == LED_STATE_TEMPORARY) {
            BO_MUST(led_switch_state(LED_STATE_NORMAL));
        }
    } break;

    default:
        break;
    }
}

int led_mode_manual_entry()
{
    if (!bo_power_is_on()) {
        return -EINVAL;
    }

    if (led_get_state() != LED_STATE_DIMMING) {
        return -EINVAL;
    }

    if (_led.settings.mode == LED_MODE_MANUAL) {
        return 0;
    }

    return 0;
}

int led_mode_scheduled_entry()
{
    if (!bo_power_is_on()) {
        return -EINVAL;
    }

    if (led_get_state() != LED_STATE_DIMMING && led_get_state() != LED_STATE_PREVIEW) {
        return -EINVAL;
    }

    if (_led.settings.mode == LED_MODE_SCHEDULED) {
        return 0;
    }

    if (led_get_state() == LED_STATE_PREVIEW) {
        BO_TRY(led_switch_state(LED_STATE_DIMMING));
    }

    return 0;
}

int led_mode_sun_entry()
{
    if (!bo_power_is_on()) {
        return -EINVAL;
    }

    if (!led_sun_can_active()) {
        return -EINVAL;
    }

    if (led_get_state() != LED_STATE_DIMMING) {
        return -EINVAL;
    }

    if (_led.settings.mode == LED_MODE_SUN) {
        return 0;
    }

    BO_TRY(led_sun_update_scheduler());

    return 0;
}

void led_render_task()
{
    led_color_t current_color;
    memcpy(current_color, LED_COLOR_BLANK, sizeof(led_color_t));

    if (bo_power_is_on()) {
        BO_MUST(led_fade_to_normal());
    }

    while (true) {
        int smf_ret = smf_run_state(SMF_CTX(&_led));
        if (smf_ret) {
            bo_panic();
        }

        // Sync color to hardware
        if (memcmp(current_color, _led.color, sizeof(led_color_t))) {
            for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
                if (current_color[ch] != _led.color[ch]) {
                    BO_MUST(led_set_channel_brightness(ch, current_color[ch]));
                    current_color[ch] = _led.color[ch];
                }
            }
        }

        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

int led_switch_state(uint8_t state)
{
    if (state >= LED_STATE_COUNT) {
        return -EINVAL;
    }

    if (led_get_state() == state) {
        return -EINVAL;
    }

    if (!bo_power_is_on()) {
        return -EINVAL;
    }

    ESP_LOGI(TAG, "Switching state from %u to %u", led_get_state(), state);

    switch (state) {

    case LED_STATE_NORMAL:
        smf_set_state(SMF_CTX(&_led), &LED_STATE_TABLE[LED_STATE_NORMAL]);
        break;

    case LED_STATE_DIMMING: {
        if (led_get_state() == LED_STATE_NORMAL || led_get_state() == LED_STATE_TEMPORARY) {
            smf_set_state(SMF_CTX(&_led), &LED_STATE_TABLE[LED_STATE_DIMMING]);
        }
        else {
            return -EINVAL;
        }
    } break;

    case LED_STATE_TEMPORARY: {
        if (led_get_state() == LED_STATE_NORMAL) {
            smf_set_state(SMF_CTX(&_led), &LED_STATE_TABLE[LED_STATE_TEMPORARY]);
        }
        else {
            return -EINVAL;
        }
    } break;

    case LED_STATE_PREVIEW: {
        if (led_get_state() == LED_STATE_DIMMING) {
            smf_set_state(SMF_CTX(&_led), &LED_STATE_TABLE[LED_STATE_PREVIEW]);
        }
        else {
            return -EINVAL;
        }
    } break;

    default:
        return -1;
    }

    BO_TRY(esp_event_post(LYFI_LED_EVENTS, LYFI_LED_STATE_CHANGED, NULL, 0, portMAX_DELAY));

    return 0;
}

int led_switch_mode(uint8_t mode)
{
    if (mode >= LED_MODE_COUNT) {
        return -EINVAL;
    }

    if (mode == _led.settings.mode) {
        return -EINVAL;
    }

    if (!(led_get_state() == LED_STATE_DIMMING || led_get_state() == LED_STATE_PREVIEW)) {
        return -EINVAL;
    }

    switch (mode) {

    case LED_MODE_MANUAL: {
        BO_TRY(led_mode_manual_entry());
    } break;

    case LED_MODE_SCHEDULED: {
        BO_TRY(led_mode_scheduled_entry());
    } break;

    case LED_MODE_SUN: {
        BO_TRY(led_mode_sun_entry());
    } break;

    default:
        return -EINVAL;
    }

    _led.settings.mode = mode;

    return 0;
}

int led_set_correction_method(uint8_t correction_method)
{
    if (correction_method >= LED_CORRECTION_COUNT) {
        return -EINVAL;
    }

    _led.settings.correction_method = correction_method;
    BO_TRY(led_save_user_settings());
    return 0;
}

static void normal_state_entry()
{
    if (_led.settings.mode == LED_MODE_SUN) {
        BO_MUST(led_sun_update_scheduler());
    }

    if (led_get_previous_state() == LED_STATE_DIMMING || led_get_previous_state() == LED_STATE_PREVIEW) {
        BO_MUST(led_save_user_settings());
    }

    if (_led.ctx.previous != NULL) {
        BO_MUST(led_fade_to_normal());
    }
}

static void normal_state_run()
{
    if (led_is_fading()) {
        led_fade_drive();
        return;
    }

    if (!bo_power_is_on()) {
        led_blank();
        return;
    }

    led_color_t color;
    time_t utc_now = time(NULL);

    switch (_led.settings.mode) {
    case LED_MODE_MANUAL: {
        memcpy(color, _led.settings.manual_color, sizeof(led_color_t));
    } break;

    case LED_MODE_SCHEDULED: {
        led_sch_drive(utc_now, color);
    } break;

    case LED_MODE_SUN: {
        led_sun_drive(utc_now, color);
    } break;

    default:
        assert(false);
        break;
    }

    // Apply filters
    if (led_acclimation_is_enabled()) {
        BO_MUST(led_acclimation_drive(utc_now, color));
    }

    BO_MUST(led_update_color(color));
}

void normal_state_exit()
{
    if (led_is_fading()) {
        BO_MUST(led_fade_stop());
    }
    return;
}

void dimming_mode_entry()
{
    if (led_is_fading()) {
        BO_MUST(led_fade_stop());
    }
    // TODO Start the timer

    ESP_LOGI(TAG, "Entering dimming mode.");

    switch (_led.settings.mode) {

    case LED_MODE_MANUAL: {
        BO_MUST(led_mode_manual_entry());
    } break;

    case LED_MODE_SCHEDULED: {
        BO_MUST(led_mode_scheduled_entry());
    } break;

    case LED_MODE_SUN: {
        BO_MUST(led_mode_sun_entry());
    } break;

    default:
        return bo_panic();
    }
}

void dimming_mode_run()
{
    //
}

void dimming_mode_exit()
{
    //
}

static void preview_state_entry()
{
    if (_led.settings.scheduler.item_count <= 1) {
        return;
    }

    memcpy(_led.color_to_resume, _led.color, sizeof(led_color_t));

    time_t utc_now = time(NULL);
    struct tm local_today = { 0 };
    localtime_r(&utc_now, &local_today);
    local_today.tm_hour = 0;
    local_today.tm_min = 0;
    local_today.tm_sec = 0;

    _led.preview_state_clock = mktime(&local_today) + _led.settings.scheduler.items[0].instant;

    ESP_LOGI(TAG, "Preview state started.");
}

static void preview_state_run()
{
    assert(led_get_state() == LED_STATE_PREVIEW);
    assert(_led.settings.scheduler.item_count > 0);

    time_t end_time
        = _led.preview_state_clock + _led.settings.scheduler.items[_led.settings.scheduler.item_count - 1].instant;
    led_color_t color;
    for (; led_get_state() == LED_STATE_PREVIEW && _led.preview_state_clock < end_time;
         _led.preview_state_clock += 60) {
        led_sch_drive(_led.preview_state_clock, color);
        BO_MUST(led_update_color(color));
        vTaskDelay(pdMS_TO_TICKS(10));
    }
    smf_set_state(SMF_CTX(&_led), &LED_STATE_TABLE[LED_STATE_DIMMING]);
}

static void preview_state_exit()
{
    _led.preview_state_clock = 0;
    led_update_color(_led.color_to_resume);
    ESP_LOGI(TAG, "Preview state ended.");
}
