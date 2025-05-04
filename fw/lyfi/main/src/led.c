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

#include <borneo/common.h>
#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>
#include <borneo/algo/astronomy.h>
#include <borneo/wifi.h>

#include "lyfi-events.h"
#include "algo.h"
#include "led.h"

static void system_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id,
                                          void* event_data);
static void led_events_handler(void* handler_args, esp_event_base_t base, int32_t id, void* event_data);

static void led_proc();

static int normal_state_entry();
static void normal_state_drive();

static int nightlight_state_entry(uint8_t prev_state);
static int nightlight_state_exit();
static void nightlight_state_drive();

static int preview_state_entry();
static void preview_state_exit();
static void preview_state_drive();

static void led_drive();

#define TAG "lyfi-ledc"

#define SECS_PER_DAY 172800
#define LED_MAX_DUTY 1023
#define LED_DUTY_RES LEDC_TIMER_10_BIT

#define FADE_PERIOD_MS 5000
#define FADE_ON_PERIOD_MS 5000
#define FADE_OFF_PERIOD_MS 3000

static led_duty_t channel_brightness_to_duty(led_brightness_t power);
static void color_to_duties(const led_color_t color, led_duty_t* duties);
static int led_set_channel_duty(uint8_t ch, led_duty_t duty);
static int led_set_duties(const led_duty_t* duties);
static int led_fade_to_color(const led_color_t color, uint32_t milssecs);
static bool led_fade_inprogress();
static int led_fade_stop();
static int led_fade_powering_on();
static void led_fade_drive();

static int led_mode_manual_entry();
static int led_mode_scheduled_entry();
static int led_mode_sun_entry();

ESP_EVENT_DEFINE_BASE(LYFI_LED_EVENTS);

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
        .duty_resolution = LEDC_TIMER_10_BIT,
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

    BO_TRY(esp_event_handler_register(LYFI_LED_EVENTS, ESP_EVENT_ANY_ID, led_events_handler, NULL));
    BO_TRY(esp_event_handler_register(BO_SYSTEM_EVENTS, ESP_EVENT_ANY_ID, system_events_handler, NULL));

    ESP_LOGI(TAG, "Starting LED controller...");

    if (_led.settings.mode == LED_MODE_SUN) {
        BO_TRY(led_sun_init());
    }

    xTaskCreate(&led_proc, "led_task", 2 * 1024, NULL, tskIDLE_PRIORITY + 2, NULL);
    ESP_LOGI(TAG, "LED Controller module has been initialized successfully.");
    return 0;
}

void led_blank()
{
    if (memcmp(_led.color, LED_COLOR_BLANK, sizeof(led_color_t)) != 0) {
        led_update_color(LED_COLOR_BLANK);
    }
}

int led_set_color(const led_color_t color)
{
    if (!bo_power_is_on() || _led.state != LED_STATE_DIMMING) {
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
    if(led_fade_inprogress()) {
        return LED_CORLUT_LOG[brightness];
    }

    switch (_led.settings.correction_method) {
    case LED_CORRECTION_CIE1931:
        return LED_CORLUT_CIE1931[brightness];

    case LED_CORRECTION_GAMMA:
        return LED_CORLUT_GAMMA[brightness];

    case LED_CORRECTION_LOG:
        return LED_CORLUT_LOG[brightness];

    case LED_CORRECTION_EXP:
        return LED_CORLUT_EXP[brightness];

    default:
        return brightness + (brightness >> 5) - (brightness >> 7);
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

int led_fade_to_color(const led_color_t color, uint32_t duration_ms)
{
    if (_led.state == LED_STATE_DIMMING) {
        return -EINVAL;
    }

    if (duration_ms < 10) {
        return -EINVAL;
    }

    int64_t now = esp_timer_get_time() / 1000LL;
    _led.fade_start_time_ms = now;
    _led.fade_duration_ms = duration_ms;
    BO_TRY(led_get_color(_led.fade_start_color));
    memcpy(_led.fade_end_color, color, sizeof(led_color_t));
    return 0;
}

int led_fade_powering_on()
{
    led_color_t end_color;

    time_t now = time(NULL) * 1000;
    now += FADE_ON_PERIOD_MS;
    now /= 1000;
    struct tm local_tm = { 0 };
    localtime_r(&now, &local_tm);

    switch (_led.settings.mode) {

    case LED_MODE_MANUAL: {
        memcpy(end_color, _led.settings.manual_color, sizeof(led_color_t));
    } break;

    case LED_MODE_SCHEDULED: {
        led_sch_compute_color(&_led.settings.scheduler, &local_tm, end_color);
    } break;

    case LED_MODE_SUN: {
        led_sch_compute_color(&_led.sun_scheduler, &local_tm, end_color);
    } break;

    default:
        assert(false);
        break;
    }

    BO_TRY(led_fade_to_color(end_color, FADE_ON_PERIOD_MS));

    return 0;
}

int led_fade_stop()
{
    _led.fade_start_time_ms = 0LL;
    BO_MUST(led_update_color(_led.fade_end_color));
    return 0;
}

void led_fade_drive()
{
    if (!led_fade_inprogress()) {
        return;
    }

    int64_t now = esp_timer_get_time() / 1000LL;
    if (now >= _led.fade_start_time_ms + _led.fade_duration_ms) {
        BO_MUST(led_fade_stop());
        return;
    }

    uint32_t elapsed_time_ms = (uint32_t)(now - _led.fade_start_time_ms);
    uint32_t progress = (elapsed_time_ms * 65536U) / _led.fade_duration_ms;

    led_color_t color;
    for (size_t ich = 0; ich < LYFI_LED_CHANNEL_COUNT; ich++) {
        int32_t delta = (int32_t)(_led.fade_end_color[ich] - _led.fade_start_color[ich]) * progress;
        color[ich] = _led.fade_start_color[ich] + (delta >> 16);
    }
    BO_MUST(led_update_color(color));
}

inline static bool led_fade_inprogress() { return _led.fade_start_time_ms > 0LL; }

int led_set_channel_brightness(uint8_t ch, led_brightness_t brightness)
{
    if (ch >= LYFI_LED_CHANNEL_COUNT || brightness > LED_BRIGHTNESS_MAX) {
        return -EINVAL;
    }
    _led.color[ch] = brightness;
    led_duty_t duty = channel_brightness_to_duty(brightness);
    BO_TRY(led_set_channel_duty(ch, duty));
    return 0;
}

int led_update_color(const led_color_t color)
{
    if (memcmp(color, _led.color, sizeof(led_color_t)) == 0) {
        return 0;
    }

    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        BO_TRY(led_set_channel_brightness(ch, color[ch]));
    }
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
        if (led_fade_inprogress()) {
            BO_MUST(led_fade_stop());
        }
        BO_MUST(led_switch_state(LED_STATE_POWERING_OFF));
        led_blank();
    } break;

    case BO_EVENT_SHUTDOWN_SCHEDULED: {
        BO_MUST(led_switch_state(LED_STATE_POWERING_OFF));
    } break;

    case BO_EVENT_POWER_ON: {
        BO_MUST(led_switch_state(LED_STATE_POWERING_ON));
    } break;

    case BO_EVENT_GEO_LOCATION_CHANGED: {
        led_sun_update_scheduler();
    } break;

    default:
        break;
    }
}

static void led_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data)
{
    switch (event_id) {

    case LYFI_LED_NOTIFY_NIGHTLIGHT_STATE: {
        assert(bo_power_is_on());
        if (_led.state == LED_STATE_NORMAL
            && (_led.settings.mode == LED_MODE_SCHEDULED || _led.settings.mode == LED_MODE_SUN)) {
            led_switch_state(LED_STATE_NIGHTLIGHT);
        }
        else if (_led.state == LED_STATE_NIGHTLIGHT) {
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

    if (_led.state != LED_STATE_DIMMING) {
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

    if (_led.state != LED_STATE_DIMMING && _led.state != LED_STATE_PREVIEW) {
        return -EINVAL;
    }

    if (_led.settings.mode == LED_MODE_SCHEDULED) {
        return 0;
    }

    if (_led.state == LED_STATE_PREVIEW) {
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

    if (_led.state != LED_STATE_DIMMING) {
        return -EINVAL;
    }

    if (_led.settings.mode == LED_MODE_SUN) {
        return 0;
    }

    BO_TRY(led_sun_update_scheduler());

    return 0;
}

void led_set_nightlight_duration(uint16_t duration) { _led.settings.nightlight_duration = duration; }

int32_t led_get_nightlight_remaining()
{
    if (_led.state == LED_STATE_NIGHTLIGHT) {
        time_t now = time(NULL);
        return (int32_t)(_led.nightlight_off_time - now);
    }
    else {
        return -1;
    }
}

////////////////////////////// Status switching //////////////////////////////////

static int normal_state_entry()
{
    uint8_t prev_state = _led.state;
    _led.state = LED_STATE_NORMAL;

    if (_led.settings.mode == LED_MODE_SUN) {
        BO_TRY(led_sun_update_scheduler());
    }

    if (prev_state == LED_STATE_DIMMING || prev_state == LED_STATE_PREVIEW) {
        ESP_LOGI(TAG, "Saving dimming settings...");
        BO_TRY(led_save_user_settings());
        ESP_LOGI(TAG, "Dimming settings updated.");
    }
    return 0;
}

static void normal_state_drive()
{
    if (led_fade_inprogress()) {
        led_fade_drive();
        return;
    }

    if (!bo_power_is_on()) {
        led_blank();
        return;
    }

    switch (_led.settings.mode) {
    case LED_MODE_MANUAL: {
        BO_MUST(led_update_color(_led.settings.manual_color));
    } break;

    case LED_MODE_SCHEDULED: {
        led_sch_drive();
    } break;

    case LED_MODE_SUN: {
        led_sun_drive();
    } break;

    default:
        assert(false);
        break;
    }
}

static int preview_state_entry()
{
    int rc = 0;

    if (_led.state != LED_STATE_DIMMING) {
        rc = -EINVAL;
        goto _EXIT;
    }

    //
    if (_led.settings.scheduler.item_count <= 1) {
        rc = -ERANGE;
        goto _EXIT;
    }

    memcpy(_led.color_to_resume, _led.color, sizeof(led_color_t));

    time_t utc_now = time(NULL);
    struct tm local_today = { 0 };
    localtime_r(&utc_now, &local_today);
    local_today.tm_hour = 0;
    local_today.tm_min = 0;
    local_today.tm_sec = 0;

    _led.preview_state_clock = mktime(&local_today) + _led.settings.scheduler.items[0].instant;

    _led.state = LED_STATE_PREVIEW;
    ESP_LOGI(TAG, "Preview state started.");

_EXIT:
    return rc;
}

static void preview_state_exit()
{
    assert(_led.state == LED_STATE_PREVIEW);
    _led.preview_state_clock = 0;
    led_update_color(_led.color_to_resume);
    ESP_LOGI(TAG, "Preview state ended.");
}

static void preview_state_drive()
{
    assert(_led.state == LED_STATE_PREVIEW);
    assert(_led.settings.scheduler.item_count > 0);

    time_t end_time
        = _led.preview_state_clock + _led.settings.scheduler.items[_led.settings.scheduler.item_count - 1].instant;
    for (; _led.state == LED_STATE_PREVIEW && _led.preview_state_clock < end_time; _led.preview_state_clock += 60) {
        led_sch_drive();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
    BO_MUST(led_switch_state(LED_STATE_DIMMING));
}

int nightlight_state_entry(uint8_t prev_state)
{
    if (!bo_power_is_on()) {
        return -EINVAL;
    }

    if (prev_state != LED_STATE_NORMAL) {
        return -EINVAL;
    }

    if (_led.settings.mode != LED_MODE_SUN && _led.settings.mode != LED_MODE_SCHEDULED) {
        return -EINVAL;
    }

    int64_t now = esp_timer_get_time() / 1000LL;

    _led.nightlight_off_time = now + (_led.settings.nightlight_duration * 1000) + FADE_PERIOD_MS * 2;
    _led.state = LED_STATE_NIGHTLIGHT;

    BO_TRY(led_fade_to_color(_led.settings.manual_color, FADE_PERIOD_MS));
    return 0;
}

static int nightlight_state_exit()
{
    if (_led.state != LED_STATE_NIGHTLIGHT) {
        return -1;
    }

    _led.nightlight_off_time = 0;
    return 0;
}

static void nightlight_state_drive()
{
    if (_led.state != LED_STATE_NIGHTLIGHT) {
        return;
    }

    int64_t now = esp_timer_get_time() / 1000LL;

    if (now >= _led.nightlight_off_time) {
        BO_MUST(led_switch_state(LED_STATE_NORMAL));
    }
    else {
        if (!led_fade_inprogress()) {
            led_update_color(_led.settings.manual_color);
        }
        else {
            led_fade_drive();
        }
    }
}

static void led_drive()
{
    switch (_led.state) {

    case LED_STATE_NORMAL: {
        normal_state_drive();
    } break;

    case LED_STATE_DIMMING: {
    } break;

    case LED_STATE_NIGHTLIGHT: {
        nightlight_state_drive();
    } break;

    case LED_STATE_PREVIEW: {
        preview_state_drive();
    } break;

    case LED_STATE_POWERING_OFF: {
        if (led_fade_inprogress()) {
            led_fade_drive();
        }
        else {
            led_blank();
            _led.state = LED_STATE_NORMAL;
        }
    } break;

    case LED_STATE_POWERING_ON: {
        if (led_fade_inprogress()) {
            led_fade_drive();
        }
        else {
            led_switch_state(LED_STATE_NORMAL);
        }
    } break;

    default:
        assert(false);
    }
}

void led_proc()
{
    while (true) {
        led_drive();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
}

int led_switch_state(uint8_t state)
{
    if (_led.state >= LED_STATE_COUNT) {
        return -EINVAL;
    }

    if (_led.state == state) {
        return 0;
    }

    ESP_LOGI(TAG, "Switching state from %u to %u", _led.state, state);

    if (state >= LED_STATE_COUNT) {
        return -EINVAL;
    }

    if (led_fade_inprogress()) {
        BO_TRY(led_fade_stop());
    }

    // Processing the previous state:
    switch (_led.state) {

    case LED_STATE_NORMAL:
    case LED_STATE_DIMMING:
        break;

    case LED_STATE_NIGHTLIGHT: {
        BO_TRY(nightlight_state_exit());
    } break;

    case LED_STATE_PREVIEW: {
        preview_state_exit();
    } break;

    case LED_STATE_POWERING_ON:
    case LED_STATE_POWERING_OFF: {
    } break;

    default:
        return -1;
    }

    switch (state) {

    case LED_STATE_NORMAL: {
        BO_TRY(normal_state_entry());
    } break;

    case LED_STATE_DIMMING: {
        if (!bo_power_is_on()) {
            return -EINVAL;
        }
        // TODO Start the timer
        if (_led.state == LED_STATE_NORMAL || _led.state == LED_STATE_PREVIEW) {
            _led.state = state;
        }
        else {
            return -EINVAL;
        }
    } break;

    case LED_STATE_NIGHTLIGHT: {
        if (!bo_power_is_on()) {
            return -EINVAL;
        }
        BO_TRY(nightlight_state_entry(_led.state));
    } break;

    case LED_STATE_PREVIEW: {
        if (!bo_power_is_on()) {
            return -EINVAL;
        }
        BO_TRY(preview_state_entry());
    } break;

    case LED_STATE_POWERING_ON: {
        _led.state = state;
        BO_TRY(led_fade_powering_on());
    } break;

    case LED_STATE_POWERING_OFF: {
        _led.state = state;
        BO_TRY(led_fade_to_color(LED_COLOR_BLANK, FADE_OFF_PERIOD_MS));
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
        return 0;
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