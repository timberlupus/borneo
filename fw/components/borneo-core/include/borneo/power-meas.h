#pragma once

#ifdef __cplusplus
extern "C" {
#endif
/* Declarations of this file */

int bo_power_meas_init();

#if CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT
int bo_power_volt_read(int* mv);
#endif

#ifdef __cplusplus
}
#endif
