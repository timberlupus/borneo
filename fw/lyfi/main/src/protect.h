#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_LYFI_PROTECTION_ENABLED

int bo_protect_init();

#if CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT
uint8_t bo_protect_get_overheated_temp();
#endif // CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT

#if CONFIG_LYFI_PROTECTION_OVERPOWER_SUPPORT
int32_t bo_protect_get_over_power_mw();
#endif // CONFIG_LYFI_PROTECTION_OVERPOWER_SUPPORT

#endif // CONFIG_LYFI_PROTECTION_ENABLED

#ifdef __cplusplus
}
#endif