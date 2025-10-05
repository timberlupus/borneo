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

// TODO
esp_err_t bo_nvs_get_or_set_i8(nvs_handle_t handle, const char* key, int8_t* value, int8_t default_value,
                               bool* changed);
esp_err_t bo_nvs_get_or_set_u8(nvs_handle_t handle, const char* key, uint8_t* value, uint8_t default_value,
                               bool* changed);
esp_err_t bo_nvs_get_or_set_i16(nvs_handle_t handle, const char* key, int16_t* value, int16_t default_value,
                                bool* changed);
esp_err_t bo_nvs_get_or_set_u16(nvs_handle_t handle, const char* key, uint16_t* value, uint16_t default_value,
                                bool* changed);
esp_err_t bo_nvs_get_or_set_i32(nvs_handle_t handle, const char* key, int32_t* value, int32_t default_value,
                                bool* changed);
esp_err_t bo_nvs_get_or_set_u32(nvs_handle_t handle, const char* key, uint32_t* value, uint32_t default_value,
                                bool* changed);
esp_err_t bo_nvs_get_or_set_i64(nvs_handle_t handle, const char* key, int64_t* value, int64_t default_value,
                                bool* changed);
esp_err_t bo_nvs_get_or_set_u64(nvs_handle_t handle, const char* key, uint64_t* value, uint64_t default_value,
                                bool* changed);
esp_err_t bo_nvs_get_or_set_str(nvs_handle_t handle, const char* key, char* value, size_t* length,
                                const char* default_value, bool* changed);
esp_err_t bo_nvs_get_or_set_blob(nvs_handle_t handle, const char* key, void* value, size_t* length,
                                 const void* default_value, size_t default_length, bool* changed);

esp_err_t bo_nvs_user_reset();

void bo_nvs_auto_close(nvs_handle_t* handle);

#ifdef __cplusplus
}
#endif