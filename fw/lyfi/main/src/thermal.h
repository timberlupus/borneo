#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct thermal_settings {
    int32_t kp; ///< PID P
    int32_t ki; ///< PID I
    int32_t kd; ///< PID D
    uint8_t keep_temp; ///< Maintaining temperature with PID
    uint8_t overheated_temp; ///< This is overheating temperature, exceeding the lighting fixture will automatically
                             ///< turn off
};

int thermal_init();
const struct thermal_settings* thermal_get_settings();
int thermal_set_pid(int32_t kp, int32_t ki, int32_t kd);
int thermal_set_keep_temp(uint8_t keep_temp);
int thermal_get_current_temp();

#ifdef __cplusplus
}
#endif