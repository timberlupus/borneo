#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_BORNEO_PROV_METHOD_NP

int bo_wifi_np_init();
int bo_wifi_np_start();

#endif // CONFIG_BORNEO_PROV_METHOD_NP

#ifdef __cplusplus
}
#endif
