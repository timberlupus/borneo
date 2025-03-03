#pragma once

#ifdef __cplusplus
extern "C" {
#endif
/* Declarations of this file */

int bo_power_meas_init();

#if CONFIG_BORNEO_MEAS_VOLTAGE_ENABLED
int bo_power_volt_read(int* mv);
#endif

#if CONFIG_BORNEO_MEAS_CURRENT_ENABLED
int bo_power_current_read(int* ma);
#endif

#ifdef __cplusplus
}
#endif
