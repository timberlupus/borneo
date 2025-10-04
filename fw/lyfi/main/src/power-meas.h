#pragma once

#ifdef __cplusplus
extern "C" {
#endif
/* Declarations of this file */

int lyfi_power_meas_init();

#if CONFIG_LYFI_MEAS_CURRENT_SUPPORT
int lyfi_power_current_read(int* ma);
#endif

#if CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT
int lyfi_power_read(int32_t* mw);
#endif

#ifdef __cplusplus
}
#endif
