#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_LYFI_PROTECTION_ENABLED
int bo_protect_init();
uint8_t bo_protect_get_overheated_temp();
int bo_protect_set_overheated_temp(uint8_t temp);

#if CONFIG_LYFI_PROTECTION_OVER_POWER_ENABLED
int32_t bo_protect_get_over_power_mw();
int bo_protect_set_over_power_mw(int32_t power_mw);
#endif // CONFIG_LYFI_PROTECTION_OVER_POWER_ENABLED

#endif // CONFIG_LYFI_PROTECTION_ENABLED

#ifdef __cplusplus
}
#endif