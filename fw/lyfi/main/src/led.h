#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define LYFI_LEDC_SCHEDULER_ITEMS_CAPACITY 48

#define LYFI_LED_CHANNEL_COUNT CONFIG_LYFI_LED_CHANNEL_COUNT


typedef uint16_t led_brightness_t;
typedef uint16_t led_duty_t;
typedef led_brightness_t led_color_t[LYFI_LED_CHANNEL_COUNT];
typedef led_duty_t led_duties_t[LYFI_LED_CHANNEL_COUNT];

#define LED_BRIGHTNESS_MIN ((led_brightness_t)0)
#define LED_BRIGHTNESS_MAX ((led_brightness_t)1000)

enum led_correction_methods {
    LED_CORRECTION_LOG = 0, ///< Default
    LED_CORRECTION_LINEAR = 1,
    LED_CORRECTION_EXP = 2,
    LED_CORRECTION_GAMMA = 3,
    LED_CORRECTION_CIE1931 = 4,

    LED_CORRECTION_COUNT,
};

enum led_status_enum {
    LED_STATE_NORMAL = 0,
    LED_STATE_DIMMING = 1,
    LED_STATE_NIGHTLIGHT = 2,
    LED_STATE_PREVIEW = 3,

    LED_STATE_COUNT,
};

enum led_running_modes {
    LED_MODE_MANUAL = 0,
    LED_MODE_SCHEDULED = 1,
    LED_MODE_SUN = 2,

    LED_MODE_COUNT,
};

enum led_option_flags {
    LED_OPTION_LUNAR_ENABLED = 1,
    LED_OPTION_ACCLIMATION_ENABLED = 2,
};

struct led_scheduler_item {
    uint32_t instant;
    led_color_t color;
};

struct led_scheduler {
    size_t item_count;
    struct led_scheduler_item items[LYFI_LEDC_SCHEDULER_ITEMS_CAPACITY];
};

struct led_factory_settings {
    uint16_t pwm_freq; ///< The frequency of PWM signals
};

struct location {
    double lat;
    double lng;
};

struct led_user_settings {
    uint8_t scheduler_enabled; ///< Whether the scheduling state is enabled
    uint16_t nightlight_duration; ///< Night lighting state duration (in seconds)
    struct led_scheduler scheduler; ///< Scheduling scheduler for scheduled state
    led_color_t manual_color; ///< Manual dimming power settings for each channel
    uint8_t correction_method; ///< Brightness correction method: Log/Exp/Linear/CIE1931

    struct location loc; ///< The location for Solar and Lunar simulation.
};

struct led_status {
    uint8_t state; ///< Current state
    led_color_t color; ///< Current hardware LED power percentage for each channel
    int64_t nightlight_off_time; ///< Time point after temporary lighting state to turn off, this time point is when
                                 ///< fading out starts
    time_t preview_state_clock; ///< Clock for preview state
    led_color_t color_to_resume; ///< Color to be resumed

    led_color_t fade_start_color;
    led_color_t fade_end_color;
    int64_t fade_start_time_ms; ///< Time point of fading started
    uint32_t fade_duration_ms; ///< The duration of fading
};

extern const led_duty_t LED_CORLUT_CIE1931[LED_BRIGHTNESS_MAX + 1];
extern const led_duty_t LED_CORLUT_LOG[LED_BRIGHTNESS_MAX + 1];
extern const led_duty_t LED_CORLUT_GAMMA[LED_BRIGHTNESS_MAX + 1];
extern const led_duty_t LED_CORLUT_EXP[LED_BRIGHTNESS_MAX + 1];

int led_init();

inline size_t led_channel_count() { return LYFI_LED_CHANNEL_COUNT; }

void led_blank();

int led_set_color(const led_color_t color);

int led_get_color(led_color_t color);

int led_get_duties(led_duty_t* duties);

led_brightness_t led_get_channel_power(uint8_t ch);

int led_set_channel_brightness(uint8_t ch, led_brightness_t value);

int led_update_color(const led_color_t color);

int led_set_schedule(const struct led_scheduler_item* items, size_t count);
const struct led_scheduler* led_get_schedule();

const struct led_user_settings* led_get_settings();

const struct led_status* led_get_status();

int led_switch_state(uint8_t state);

bool led_is_blank();

int led_set_scheduler_enabled(bool enabled);

void led_set_nightlight_duration(uint16_t duration);
int32_t led_get_nightlight_remaining();

int led_set_correction_method(uint8_t correction_method);

int led_load_factory_settings(struct led_factory_settings* factory_settings);
int led_load_user_settings(struct led_user_settings* settings);
int led_save_user_settings(const struct led_user_settings* settings);

#ifdef __cplusplus
}
#endif