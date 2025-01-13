#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if !CONFIG_BT_BLE_BLUFI_ENABLE

int bo_wifi_sc_init();
int bo_wifi_sc_start();

#endif // CONFIG_BT_BLE_BLUFI_ENABLE

#ifdef __cplusplus
}
#endif