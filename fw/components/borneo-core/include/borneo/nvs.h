#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define BO_NVS_AUTO_CLOSE(handle) __attribute__((cleanup(bo_nvs_auto_close))) nvs_handle_t handle##_##__LINE__ = handle

esp_err_t bo_nvs_init();

esp_err_t bo_nvs_factory_open(const char* name, nvs_open_mode_t open_mode, nvs_handle_t* out_handle);
esp_err_t bo_nvs_user_open(const char* name, nvs_open_mode_t open_mode, nvs_handle_t* out_handle);
void bo_nvs_close(nvs_handle_t handle);

esp_err_t bo_nvs_get_i8_or(nvs_handle_t h, const char* key, int8_t* val);
esp_err_t bo_nvs_get_u8_or(nvs_handle_t h, const char* key, uint8_t* val);
esp_err_t bo_nvs_get_i16_or(nvs_handle_t h, const char* key, int16_t* val);
esp_err_t bo_nvs_get_u16_or(nvs_handle_t h, const char* key, uint16_t* val);
esp_err_t bo_nvs_get_i32_or(nvs_handle_t h, const char* key, int32_t* val);
esp_err_t bo_nvs_get_u32_or(nvs_handle_t h, const char* key, uint32_t* val);
esp_err_t bo_nvs_get_i64_or(nvs_handle_t h, const char* key, int64_t* val);
esp_err_t bo_nvs_get_u64_or(nvs_handle_t h, const char* key, uint64_t* val);

esp_err_t bo_nvs_user_reset();

void bo_nvs_auto_close(nvs_handle_t* handle);

#ifdef __cplusplus
}
#endif