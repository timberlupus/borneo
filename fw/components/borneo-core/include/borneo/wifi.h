#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int bo_wifi_init();
int bo_wifi_forget();
int bo_wifi_get_rssi(int* rssi);
bool bo_wifi_configurated();

#ifdef __cplusplus
}
#endif