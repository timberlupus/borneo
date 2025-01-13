#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_BT_BLE_BLUFI_ENABLE

int bo_wifi_blufi_init();
int bo_wifi_blufi_start();

#endif // CONFIG_BT_BLE_BLUFI_ENABLE

#ifdef __cplusplus
}
#endif