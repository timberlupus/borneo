#pragma once

#ifdef __cplusplus
extern "C" {
#endif

enum {
    POWER_LAST_POWER_STATE = 0, ///< Preserve last power state
    POWER_AUTO_POWER_ON = 1, ///< Auto power on
    POWER_MAINTAIN_POWER_OFF = 2, ///< Maintain power off
    POWER_INVALID_BEHAVIOR = 3, ///< Maintain power off
};

int bo_power_init();

bool bo_power_is_on();

int bo_power_on();

int bo_power_off();

int bo_power_shutdown(uint32_t reason);

uint8_t bo_power_get_behavior();

int bo_power_set_behavior(uint8_t behavior);

#ifdef __cplusplus
}
#endif