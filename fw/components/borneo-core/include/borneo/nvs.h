#pragma once

#ifdef __cplusplus
extern "C" {
#endif

esp_err_t bo_nvs_init();

esp_err_t bo_nvs_factory_open(const char* name, nvs_open_mode_t open_mode, nvs_handle_t* out_handle);
esp_err_t bo_nvs_user_open(const char* name, nvs_open_mode_t open_mode, nvs_handle_t* out_handle);
void bo_nvs_close(nvs_handle_t handle);

esp_err_t bo_nvs_user_reset();

#ifdef __cplusplus
}
#endif