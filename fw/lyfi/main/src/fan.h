#pragma once

#ifdef __cplusplus
extern "C" {
#endif

enum fan_flags_enum {
    FAN_FLAG_DAC_ENABLED = 1,
    FAN_FLAG_PWM_ENABLED = 2,
};

enum fan_power_range {
    FAN_POWER_MIN = 0,
    FAN_POWER_MAX = 100,
};

struct fan_status {
    volatile uint8_t power;
};

struct fan_factory_settings {
    uint32_t flags;
};

int fan_init();

int fan_set_power(uint8_t value);
uint8_t fan_get_power();

struct fan_status fan_get_status();

#ifdef __cplusplus
}
#endif