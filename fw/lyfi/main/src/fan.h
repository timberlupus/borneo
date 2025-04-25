#pragma once

#ifdef __cplusplus
extern "C" {
#endif

enum fan_power_range {
    FAN_POWER_MIN = 0,
    FAN_POWER_MAX = 100,
};

struct fan_status {
    volatile uint8_t power;
};

struct fan_settings {
    uint8_t use_pwm_fan;
};

int fan_init();

int fan_set_power(uint8_t value);
uint8_t fan_get_power();

struct fan_status fan_get_status();
const struct fan_settings* fan_get_settings();

#ifdef __cplusplus
}
#endif