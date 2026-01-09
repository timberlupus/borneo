#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_BORNEO_PROV_METHOD_SC

int bo_wifi_sc_init();
int bo_wifi_sc_start();

#endif // CONFIG_BORNEO_PROV_METHOD_SC

#ifdef __cplusplus
}
#endif