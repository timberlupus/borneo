#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_LYFI_PROTECTION_ENABLED
int bo_protect_init();
uint8_t bo_protect_get_overheated_temp();
#endif // CONFIG_LYFI_PROTECTION_ENABLED

#ifdef __cplusplus
}
#endif