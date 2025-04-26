#include <string.h>
#include <time.h>
#include <errno.h>

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

#include "lyfi-events.h"
#include "algo.h"
#include "led.h"

static void sch_compute_current_duties(led_color_t color, led_duty_t* duties);
static void sch_compute_color_in_range(led_color_t color, const struct tm* now,
                                       const struct led_scheduler_item* range_begin,
                                       const struct led_scheduler_item* range_end);
static void sch_compute_duties_in_range(led_duty_t* duties, const struct tm* now,
                                        const struct led_scheduler_item* range_begin,
                                        const struct led_scheduler_item* range_end);

static void _borneo_system_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id,
                                          void* event_data);
static void led_events_handler(void* handler_args, esp_event_base_t base, int32_t id, void* event_data);

static void led_proc();

static int normal_mode_entry();
static void normal_mode_drive();

// static int dimming_mode_entry();
// static void dimming_mode_drive();
struct sch_time_pair {
    const struct led_scheduler_item* begin;
    const struct led_scheduler_item* end;
};

static int sch_find_closest_time_range(uint32_t instant, struct sch_time_pair* result);
static void sch_drive();

static int nightlight_mode_entry();
static int nightlight_mode_exit();
static void nightlight_mode_drive();

static int preview_mode_entry();
static void preview_mode_exit();
static void preview_mode_drive();

static void led_drive();

static int load_factory_settings(struct led_factory_settings* factory_settings);

static int load_user_settings();
static int save_user_settings();

ledc_channel_config_t _ledc_channels[LYFI_LED_CHANNEL_COUNT];

#define TAG "lyfi-ledc"

#define LED_NVS_NS "led"
#define LED_NVS_KEY_SCHEDULER_ENABLED "sch_en"
#define LED_NVS_KEY_MANUAL_COLOR "mcolor"
#define LED_NVS_KEY_SCHEDULER "sch"
#define LED_NVS_KEY_NIGHTLIGHT_DURATION "nld"
#define LED_NVS_KEY_CORRECTION_METHOD "corrmtd"
#define LED_NVS_KEY_PWM_FREQ "pwmfreq"

#define LED_MAX_DUTY 1023
#define LED_DUTY_RES LEDC_TIMER_10_BIT
#define SECS_PER_DAY 172800

#define FADE_PERIOD_MS 5000
#define FADE_OFF_PERIOD_MS 3000

static led_duty_t channel_brightness_to_duty(led_brightness_t power);
static void color_to_duties(const led_color_t color, led_duty_t* duties);
static int led_set_channel_duty(uint8_t ch, led_duty_t duty);
static int led_set_duties(const led_duty_t* duties);
static int led_fade_to_color(const led_color_t color, uint32_t milssecs);
static int led_fade_on(uint32_t milssecs);
static int led_fade_off(uint32_t milssecs);
static bool led_fade_inprogress();
static int led_fade_stop();
static void led_fade_drive();

ESP_EVENT_DEFINE_BASE(LYFI_LEDC_EVENTS);

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

static const led_color_t COLOR_BLANK = { 0 };

static const struct led_user_settings LED_DEFAULT_SETTINGS = {
    .scheduler_enabled = 0,
    .nightlight_duration = 60 * 20,
    .manual_color = {
// From kconfig
#if CONFIG_LYFI_LED_CH0_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH1_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH2_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH3_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH4_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH5_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH6_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH7_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH8_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH9_ENABLED
        10,
#endif
    },
    .scheduler = { 0 },
};

static struct led_status _status;
static struct led_user_settings _settings;

/**
 * Initialize the LED controller
 *
 */
int led_init()
{
    ESP_LOGI(TAG, "Initializing LED controller....");

    memset(&_status, 0, sizeof(_status));
    memset(&_settings, 0, sizeof(_settings));
    memset(_ledc_channels, 0, sizeof(_ledc_channels));

    struct led_factory_settings factory_settings;
    BO_TRY(load_factory_settings(&factory_settings));

    BO_TRY(load_user_settings());

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

    // 加载配置
    BO_TRY(esp_event_handler_instance_register(LYFI_LEDC_EVENTS, ESP_EVENT_ANY_ID, led_events_handler, NULL, NULL));
    BO_TRY(esp_event_handler_instance_register(BO_SYSTEM_EVENTS, ESP_EVENT_ANY_ID, _borneo_system_events_handler, NULL,
                                               NULL));

    ESP_LOGI(TAG, "Starting LED controller...");

    xTaskCreate(&led_proc, "led_task", 2 * 1024, NULL, tskIDLE_PRIORITY, NULL);
    ESP_LOGI(TAG, "LED Controller module has been initialized successfully.");
    return 0;
}

void led_blank()
{
    //
    led_update_color(COLOR_BLANK);
}

int led_set_color(const led_color_t color)
{
    if (!bo_power_is_on() || _status.mode != LED_MODE_DIMMING) {
        return -EINVAL;
    }
    // Verify the colors
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        if (color[ch] > LED_BRIGHTNESS_MAX) {
            return -EINVAL;
        }
    }

    if (!_settings.scheduler_enabled) {
        memcpy(_settings.manual_color, color, sizeof(led_color_t));
    }

    BO_TRY(led_update_color(color));

    return 0;
}

int led_get_color(led_color_t color)
{
    memcpy(color, _status.color, sizeof(led_color_t));
    return ESP_OK;
}

led_brightness_t led_get_channel_power(uint8_t ch)
{
    //
    assert(ch < LYFI_LED_CHANNEL_COUNT);
    return _status.color[ch];
}

inline led_duty_t channel_brightness_to_duty(led_brightness_t brightness)
{
    switch (_settings.correction_method) {
    case LED_CORRECTION_CIE1931:
        return LED_CORLUT_CIE1931[brightness];

    case LED_CORRECTION_EXP:
        return LED_CORLUT_EXP[brightness];

    case LED_CORRECTION_LOG:
        return LED_CORLUT_LOG[brightness];

    default:
        return brightness;
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
    if (_status.mode == LED_MODE_DIMMING) {
        return -EINVAL;
    }

    if (duration_ms < 10) {
        return -EINVAL;
    }

    int64_t now = esp_timer_get_time() / 1000LL;
    _status.fade_start_time_ms = now;
    _status.fade_duration_ms = duration_ms;
    BO_TRY(led_get_color(_status.fade_start_color));
    memcpy(_status.fade_end_color, color, sizeof(led_color_t));
    return 0;
}

static int led_fade_on(uint32_t ms)
{
    if (!_settings.scheduler_enabled) {
        BO_TRY(led_fade_to_color(_settings.manual_color, ms));
    }
    return 0;
}

static int led_fade_off(uint32_t ms)
{
    if (_status.mode != LED_MODE_NORMAL && _status.mode != LED_MODE_NIGHTLIGHT) {
        return -EINVAL;
    }

    BO_TRY(led_fade_to_color(COLOR_BLANK, ms));
    return 0;
}

int led_fade_stop()
{
    if (!led_fade_inprogress()) {
        return -EINVAL;
    }
    _status.fade_start_time_ms = 0LL;
    return 0;
}

void led_fade_drive()
{
    if (!led_fade_inprogress()) {
        return;
    }

    led_duties_t start_duties, end_duties;
    color_to_duties(_status.fade_start_color, start_duties);
    color_to_duties(_status.fade_end_color, end_duties);
    int64_t now = esp_timer_get_time() / 1000LL;
    if (now >= _status.fade_start_time_ms + _status.fade_duration_ms) {
        BO_MUST(led_fade_stop());
    }

    uint32_t elapsed_time_ms = (uint32_t)(now - _status.fade_start_time_ms);
    led_duties_t duties;
    for (size_t ich = 0; ich < LYFI_LED_CHANNEL_COUNT; ich++) {
        int16_t duty_delta = (int16_t)(end_duties[ich] - start_duties[ich]);
        led_duty_t duty = start_duties[ich] + duty_delta * elapsed_time_ms / _status.fade_duration_ms;
        if (duty > end_duties[ich]) {
            duty = end_duties[ich];
        }
        duties[ich] = duty;
    }
    BO_MUST(led_set_duties(duties));
}

inline static bool led_fade_inprogress() { return _status.fade_start_time_ms > 0LL; }

int led_set_channel_brightness(uint8_t ch, led_brightness_t brightness)
{
    if (ch >= LYFI_LED_CHANNEL_COUNT || brightness > LED_BRIGHTNESS_MAX) {
        return -EINVAL;
    }
    _status.color[ch] = brightness;
    led_duty_t duty = channel_brightness_to_duty(brightness);
    BO_TRY(led_set_channel_duty(ch, duty));
    return 0;
}

int led_update_color(const led_color_t color)
{
    if (memcmp(color, _status.color, sizeof(led_color_t)) == 0) {
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
        memcpy(_settings.scheduler.items, items, sizeof(struct led_scheduler_item) * count);
        _settings.scheduler.item_count = count;
    }
    else {
        memset(&_settings.scheduler, 0, sizeof(_settings.scheduler));
    }

    return 0;
}

const struct led_scheduler* led_get_schedule() { return &_settings.scheduler; }

const struct led_user_settings* led_get_settings() { return &_settings; }

const struct led_status* led_get_status() { return &_status; }

int sch_find_closest_time_range(uint32_t instant, struct sch_time_pair* result)
{
    if (result == NULL) {
        return -EINVAL;
    }

    if (_settings.scheduler.item_count == 0) {
        return -ENOENT;
    }

    const struct led_scheduler_item* items = _settings.scheduler.items;
    size_t size = _settings.scheduler.item_count;

    result->begin = NULL;
    result->end = NULL;

    if (instant < items[0].instant) {
        return -ENOENT;
    }

    for (size_t i = 0; i < size; i++) {
        if (instant < items[i].instant) {
            if (i == 0) {
                return -ENOENT;
            }
            else {
                result->begin = &items[i - 1];
                result->end = &items[i];
                return 0;
            }
        }
    }
    // now_instant >= all items
    result->begin = &items[size - 1];
    return 0;
}

void sch_compute_color_in_range(led_color_t color, const struct tm* now, const struct led_scheduler_item* range_begin,
                                const struct led_scheduler_item* range_end)
{
    int32_t now_instant = (now->tm_hour * 3600) + (now->tm_min * 60) + now->tm_sec;
    if (range_begin->instant >= SECS_PER_DAY) {
        now_instant += SECS_PER_DAY;
    }

    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        led_brightness_t begin_brightness = range_begin->color[ch];
        led_brightness_t end_brightness = range_end->color[ch];
        int32_t value = linear_interpolate_i32(range_begin->instant, begin_brightness, range_end->instant,
                                               end_brightness, now_instant);
        if (value < 0) {
            value = 0;
        }
        else if (value > LED_BRIGHTNESS_MAX) {
            value = LED_BRIGHTNESS_MAX;
        }
        color[ch] = value;
    }
}

void sch_compute_duties_in_range(led_duty_t* duties, const struct tm* now, const struct led_scheduler_item* range_begin,
                                 const struct led_scheduler_item* range_end)
{
    int32_t now_instant = (now->tm_hour * 3600) + (now->tm_min * 60) + now->tm_sec;
    if (range_begin->instant >= SECS_PER_DAY) {
        now_instant += SECS_PER_DAY;
    }

    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        led_duty_t begin_duty = channel_brightness_to_duty(range_begin->color[ch]);
        led_duty_t end_duty = channel_brightness_to_duty(range_end->color[ch]);
        int32_t value
            = linear_interpolate_i32(range_begin->instant, begin_duty, range_end->instant, end_duty, now_instant);
        if (value < 0) {
            value = 0;
        }
        else if (value > LED_MAX_DUTY) {
            value = LED_MAX_DUTY;
        }
        duties[ch] = (led_duty_t)value;
    }
}

void sch_compute_current_duties(led_color_t color, led_duty_t* duties)
{
    assert(_status.mode == LED_MODE_PREVIEW || _settings.scheduler_enabled);

    if (_settings.scheduler.item_count == 0) {
        memset(color, 0, sizeof(led_color_t));
        memset(duties, 0, sizeof(led_duties_t));
        return;
    }

    time_t utc_now = _status.mode == LED_MODE_PREVIEW ? _status.preview_mode_clock : time(NULL);

    struct tm local_now = { 0 };
    localtime_r(&utc_now, &local_now);
    uint32_t local_instant = (local_now.tm_hour * 3600) + (local_now.tm_min * 60) + local_now.tm_sec;
    uint32_t local_next_day_instant = SECS_PER_DAY + local_instant;

    // Find the instant range
    struct sch_time_pair pair;

    int rc = sch_find_closest_time_range(local_instant, &pair);
    if (rc == -ENOENT) { // Try the time of next day
        rc = sch_find_closest_time_range(local_next_day_instant, &pair);
    }
    if (rc && rc != -ENOENT) {
        // we got an error
        ESP_LOGE(TAG, "Failed to find scheduler item with instant(%lu), errno=%d", local_instant, rc);
        memset(duties, 0, sizeof(led_duties_t));
        memset(color, 0, sizeof(led_color_t));
        return;
    }

    // Open range
    if (pair.begin != NULL && pair.end == NULL) {
        color_to_duties(pair.begin->color, duties);
        memcpy(color, pair.begin->color, sizeof(led_color_t));
        return;
    }

    // Between two instants
    if (pair.begin != NULL && pair.end != NULL) {
        sch_compute_color_in_range(color, &local_now, pair.begin, pair.end);
        sch_compute_duties_in_range(duties, &local_now, pair.begin, pair.end);
    }
}

static void sch_drive()
{
    assert(_status.mode == LED_MODE_PREVIEW || _settings.scheduler_enabled);

    led_duties_t duties;
    led_color_t color;
    sch_compute_current_duties(color, duties);

    memcpy(_status.color, color, sizeof(led_color_t));
    BO_MUST(led_set_duties(duties));
}

bool led_is_blank()
{
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        if (_status.color[ch] > 0) {
            return false;
        }
    }
    return true;
}

static void _borneo_system_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data)
{
    switch (event_id) {
    case BO_EVENT_SHUTDOWN_SCHEDULED:
    case BO_EVENT_EMERGENCY_SHUTDOWN:
    case BO_EVENT_FATAL_ERROR: {
        if (_status.mode != LED_MODE_NORMAL) {
            BO_MUST(led_switch_mode(LED_MODE_NORMAL));
        }
        if (led_fade_inprogress()) {
            BO_MUST(led_fade_stop());
        }
        led_blank();
    } break;

    case BO_EVENT_POWER_OFF: {
        if (_status.mode != LED_MODE_NORMAL) {
            BO_MUST(led_switch_mode(LED_MODE_NORMAL));
        }
        if (led_fade_inprogress()) {
            BO_MUST(led_fade_stop());
        }
        BO_MUST(led_fade_off(FADE_OFF_PERIOD_MS));
    } break;

    case BO_EVENT_POWER_ON: {
        BO_MUST(led_fade_on(FADE_PERIOD_MS));
        BO_MUST(normal_mode_entry());
    } break;

    default:
        break;
    }
}

static void led_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data)
{
    switch (event_id) {

    case LYFI_LEDC_NOTIFY_NIGHTLIGHT_MODE: {
        assert(bo_power_is_on());
        if (_status.mode == LED_MODE_NORMAL && _settings.scheduler_enabled) {
            led_switch_mode(LED_MODE_NIGHTLIGHT);
        }
        else if (_status.mode == LED_MODE_NIGHTLIGHT) {
            BO_MUST(led_switch_mode(LED_MODE_NORMAL));
        }
    } break;

    default:
        break;
    }
}

int led_set_scheduler_enabled(bool enabled)
{

    if (!bo_power_is_on() || (_status.mode != LED_MODE_DIMMING && _status.mode != LED_MODE_PREVIEW)) {
        return -EINVAL;
    }

    if (_status.mode == LED_MODE_PREVIEW) {
        BO_TRY(led_switch_mode(LED_MODE_DIMMING));
    }

    _settings.scheduler_enabled = enabled;

    if (!_settings.scheduler_enabled) {
        BO_TRY(led_set_color(_settings.manual_color));
    }

    return 0;
}

void led_set_nightlight_duration(uint16_t duration) { _settings.nightlight_duration = duration; }

int32_t led_get_nightlight_remaining()
{
    if (_status.mode == LED_MODE_NIGHTLIGHT) {
        time_t now = time(NULL);
        return (int32_t)(_status.nightlight_off_time - now);
    }
    else {
        return -1;
    }
}

////////////////////////////// Status switching //////////////////////////////////

static int normal_mode_entry()
{
    uint8_t prev_mode = _status.mode;
    _status.mode = LED_MODE_NORMAL;

    if (!led_fade_inprogress()) {
        if (_settings.scheduler_enabled) {
            sch_drive();
        }
        else {
            BO_TRY(led_update_color(_settings.manual_color));
        }
    }

    if (prev_mode == LED_MODE_DIMMING || prev_mode == LED_MODE_PREVIEW) {
        ESP_LOGI(TAG, "Saving dimming settings...");
        BO_TRY(save_user_settings());
        ESP_LOGI(TAG, "Dimming settings updated.");
    }
    return 0;
}

static void normal_mode_drive()
{
    if (!led_fade_inprogress()) {
        if (_settings.scheduler_enabled) {
            sch_drive();
        }
        else {
            BO_MUST(led_update_color(_settings.manual_color));
        }
    }
}

static int preview_mode_entry()
{
    int rc = 0;

    if (_status.mode != LED_MODE_DIMMING) {
        rc = -EINVAL;
        goto _EXIT;
    }

    //
    if (_settings.scheduler.item_count <= 1) {
        rc = -ERANGE;
        goto _EXIT;
    }

    memcpy(_status.color_to_resume, _status.color, sizeof(led_color_t));

    time_t utc_now = time(NULL);
    struct tm local_today = { 0 };
    localtime_r(&utc_now, &local_today);
    local_today.tm_hour = 0;
    local_today.tm_min = 0;
    local_today.tm_sec = 0;

    _status.preview_mode_clock = mktime(&local_today) + _settings.scheduler.items[0].instant;

    _status.mode = LED_MODE_PREVIEW;
    ESP_LOGI(TAG, "Preview mode started.");

_EXIT:
    return rc;
}

static void preview_mode_exit()
{
    assert(_status.mode == LED_MODE_PREVIEW);
    led_update_color(_status.color_to_resume);
    ESP_LOGI(TAG, "Preview mode ended.");
}

static void preview_mode_drive()
{
    assert(_status.mode == LED_MODE_PREVIEW);
    assert(_settings.scheduler.item_count > 0);

    time_t end_time
        = _status.preview_mode_clock + _settings.scheduler.items[_settings.scheduler.item_count - 1].instant;
    for (; _status.mode == LED_MODE_PREVIEW && _status.preview_mode_clock < end_time;
         _status.preview_mode_clock += 60) {
        sch_drive();
        // taskYIELD();
        vTaskDelay(pdMS_TO_TICKS(10));
    }
    BO_MUST(led_switch_mode(LED_MODE_DIMMING));
}

int nightlight_mode_entry()
{
    if (!_settings.scheduler_enabled || _status.mode != LED_MODE_NORMAL || !bo_power_is_on()) {
        return -EINVAL;
    }

    int64_t now = esp_timer_get_time() / 1000ULL;

    _status.nightlight_off_time = now + (_settings.nightlight_duration * 1000) + FADE_PERIOD_MS;
    _status.mode = LED_MODE_NIGHTLIGHT;

    BO_TRY(led_fade_to_color(_settings.manual_color, FADE_PERIOD_MS));
    return 0;
}

static int nightlight_mode_exit()
{
    if (_status.mode != LED_MODE_NIGHTLIGHT) {
        return -1;
    }

    _status.nightlight_off_time = 0;

    BO_TRY(led_fade_on(FADE_OFF_PERIOD_MS));
    return 0;
}

static void nightlight_mode_drive()
{
    if (_status.mode != LED_MODE_NIGHTLIGHT) {
        return;
    }

    int64_t now = esp_timer_get_time() / 1000ULL;

    if (now >= _status.nightlight_off_time) {
        BO_MUST(led_switch_mode(LED_MODE_NORMAL));
    }
    else {
        if (!led_fade_inprogress()) {
            led_update_color(_settings.manual_color);
        }
    }
}

static void led_drive()
{
    if (_status.fade_start_time_ms > 0LL) {
        led_fade_drive();
    }
    else {

        switch (_status.mode) {

        case LED_MODE_NORMAL: {
            normal_mode_drive();
        } break;

        case LED_MODE_DIMMING: {
        } break;

        case LED_MODE_NIGHTLIGHT: {
            nightlight_mode_drive();
        } break;

        case LED_MODE_PREVIEW: {
            preview_mode_drive();
        } break;

        default:
            assert(false);
        }
    }
}

void led_proc()
{
    if (bo_power_is_on()) {
        BO_MUST(led_fade_on(FADE_PERIOD_MS));
    }

    BO_MUST(normal_mode_entry());
    while (true) {
        if (bo_power_is_on()) {
            led_drive();
        }
        else {
            led_blank();
        }
        taskYIELD();
    }
}

int led_switch_mode(uint8_t mode)
{
    if (_status.mode == mode) {
        return -EINVAL;
    }

    ESP_LOGI(TAG, "Switching mode from %d to %d", _status.mode, mode);

    if (!bo_power_is_on() || mode == _status.mode) {
        return -EINVAL;
    }

    if (mode >= LED_MODE_COUNT) {
        return -EINVAL;
    }

    if (led_fade_inprogress()) {
        BO_TRY(led_fade_stop());
    }

    switch (_status.mode) {

    case LED_MODE_NORMAL:
    case LED_MODE_DIMMING:
        break;

    case LED_MODE_NIGHTLIGHT: {
        BO_TRY(nightlight_mode_exit());
    } break;

    case LED_MODE_PREVIEW: {
        preview_mode_exit();
    } break;

    default:
        return -1;
    }

    switch (mode) {

    case LED_MODE_NORMAL: {
        if (_status.mode == LED_MODE_DIMMING || _status.mode == LED_MODE_PREVIEW
            || _status.mode == LED_MODE_NIGHTLIGHT) {
            BO_TRY(normal_mode_entry());
        }
        else {
            return -EINVAL;
        }
    } break;

    case LED_MODE_DIMMING: {
        // TODO Start the timer
        if (_status.mode == LED_MODE_NORMAL || _status.mode == LED_MODE_PREVIEW) {
            _status.mode = mode;
        }
        else {
            return -EINVAL;
        }
    } break;

    case LED_MODE_NIGHTLIGHT: {
        BO_TRY(nightlight_mode_entry());
    } break;

    case LED_MODE_PREVIEW: {
        BO_TRY(preview_mode_entry());
    } break;

    default:
        return -1;
    }

    BO_TRY(esp_event_post(LYFI_LEDC_EVENTS, LYFI_LEDC_MODE_CHANGED, NULL, 0, portMAX_DELAY));

    return 0;
}

/////////////////////////////////// Settings stuff /////////////////////////////////////////////

int load_factory_settings(struct led_factory_settings* factory_settings)
{
    int rc;
    nvs_handle_t handle;
    rc = bo_nvs_factory_open(LED_NVS_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    rc = nvs_get_u16(handle, LED_NVS_KEY_PWM_FREQ, &factory_settings->pwm_freq);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        factory_settings->pwm_freq = CONFIG_LYFI_DEFAULT_PWM_FREQ;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }


_EXIT_CLOSE:
    bo_nvs_close(handle);
_EXIT_WITHOUT_CLOSE:
    return rc;
}

int load_user_settings()
{
    int rc;
    nvs_handle_t handle;
    rc = bo_nvs_user_open(LED_NVS_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    rc = nvs_get_u8(handle, LED_NVS_KEY_SCHEDULER_ENABLED, &_settings.scheduler_enabled);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.scheduler_enabled = LED_DEFAULT_SETTINGS.scheduler_enabled;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_get_u16(handle, LED_NVS_KEY_NIGHTLIGHT_DURATION, &_settings.nightlight_duration);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.nightlight_duration = LED_DEFAULT_SETTINGS.nightlight_duration;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    size_t size = sizeof(struct led_scheduler);

    rc = nvs_get_blob(handle, LED_NVS_KEY_SCHEDULER, &_settings.scheduler, &size);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        memcpy(&_settings.scheduler, &LED_DEFAULT_SETTINGS.scheduler, sizeof(struct led_scheduler));
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    size = sizeof(led_color_t);
    rc = nvs_get_blob(handle, LED_NVS_KEY_MANUAL_COLOR, &_settings.manual_color, &size);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        memcpy(&_settings.manual_color, &LED_DEFAULT_SETTINGS.manual_color, sizeof(led_color_t));
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_get_u8(handle, LED_NVS_KEY_CORRECTION_METHOD, &_settings.correction_method);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.correction_method = LED_DEFAULT_SETTINGS.correction_method;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    // TODO
    // Loading the brightness and power settings...
#ifdef CONFIG_LYFI_STANDALONE_CONTROLLER
#endif // CONFIG_LYFI_STANDALONE_CONTROLLER

_EXIT_CLOSE:
    bo_nvs_close(handle);
_EXIT_WITHOUT_CLOSE:
    return rc;
}

int save_user_settings()
{
    int rc;
    nvs_handle_t handle;
    rc = bo_nvs_user_open(LED_NVS_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    rc = nvs_set_u8(handle, LED_NVS_KEY_SCHEDULER_ENABLED, _settings.scheduler_enabled);
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_u16(handle, LED_NVS_KEY_NIGHTLIGHT_DURATION, _settings.nightlight_duration);
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_u8(handle, LED_NVS_KEY_CORRECTION_METHOD, _settings.correction_method);
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_blob(handle, LED_NVS_KEY_SCHEDULER, &_settings.scheduler, sizeof(struct led_scheduler));
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_blob(handle, LED_NVS_KEY_MANUAL_COLOR, _settings.manual_color, sizeof(led_color_t));
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_commit(handle);

_EXIT_CLOSE:
    bo_nvs_close(handle);
_EXIT_WITHOUT_CLOSE:
    return rc;
}

int led_set_correction_method(uint8_t correction_method)
{
    // TODO add lock
    if (correction_method >= LED_CORRECTION_COUNT) {
        return -EINVAL;
    }

    _settings.correction_method = correction_method;
    BO_TRY(save_user_settings());
    return 0;
}