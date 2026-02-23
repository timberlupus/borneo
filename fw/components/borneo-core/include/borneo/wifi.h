#pragma once

#ifdef __cplusplus
extern "C" {
#endif

ESP_EVENT_DECLARE_BASE(BO_WIFI_EVENTS);

enum {
    BO_EVENT_WIFI_PROVISIONING_START = 0, ///< Power-on start initialization
    BO_EVENT_WIFI_PROVISIONING_SUCCESS, ///< Power-on start initialization
    BO_EVENT_WIFI_PROVISIONING_FAIL, ///< Power-on start initialization
};

int bo_wifi_init();
int bo_wifi_forget();
int bo_wifi_forget_later(uint32_t delay_ms);
int bo_wifi_get_rssi(int* rssi);
bool bo_wifi_configurated();

#ifdef __cplusplus
}
#endif