#pragma once

#ifdef __cplusplus
extern "C" {
#endif
/* Declarations of this file */

//#if CONFIG_BORNEO_POWER_MEASUREMENT_ENABLED

int bo_power_meas_init();
int bo_power_volt_read(int* voltage);
int bo_power_current_read(int* voltage);

//#endif // CONFIG_BORNEO_NTC_ENABLED

#ifdef __cplusplus
}
#endif

