
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <esp_log.h>
#include <esp_system.h>
#include <esp_timer.h>
#include <esp_rom_md5.h>
#include <esp_event.h>
#include <nvs_flash.h>

#include <borneo/common.h>
#include <borneo/system.h>
#include <borneo/power.h>

#include <borneo/nvs.h>

#define NVS_FACTORY_PART_NAME "nvs_factory"
#define TAG "bo_nvs"

esp_err_t bo_nvs_init()
{

    esp_err_t rc;
    rc = nvs_flash_init_partition(NVS_DEFAULT_PART_NAME);
    if (rc == ESP_ERR_NVS_NO_FREE_PAGES || rc == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        rc = nvs_flash_erase_partition(NVS_DEFAULT_PART_NAME);
        if (rc) {
            return rc;
        }
        rc = nvs_flash_init_partition(NVS_DEFAULT_PART_NAME);
        if (rc) {
            return rc;
        }
    }

    rc = nvs_flash_init_partition(NVS_FACTORY_PART_NAME);
    if (rc == ESP_ERR_NVS_NO_FREE_PAGES || rc == ESP_ERR_NVS_NEW_VERSION_FOUND) {
        rc = nvs_flash_erase_partition(NVS_FACTORY_PART_NAME);
        if (rc) {
            return rc;
        }
        rc = nvs_flash_init_partition(NVS_FACTORY_PART_NAME);
    }

    return rc;
}

esp_err_t bo_nvs_factory_open(const char* name, nvs_open_mode_t open_mode, nvs_handle_t* out_handle)
{
    BO_TRY_ESP(nvs_open_from_partition(NVS_FACTORY_PART_NAME, name, open_mode, out_handle));
    return 0;
}

esp_err_t bo_nvs_user_open(const char* name, nvs_open_mode_t open_mode, nvs_handle_t* out_handle)
{
    BO_TRY_ESP(nvs_open_from_partition(NVS_DEFAULT_PART_NAME, name, open_mode, out_handle));
    return 0;
}

void bo_nvs_close(nvs_handle_t handle) { nvs_close(handle); }

esp_err_t bo_nvs_get_i8_or(nvs_handle_t h, const char* key, int8_t* val)
{
    if (val == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    int8_t tmp;
    esp_err_t err = nvs_get_i8(h, key, &tmp);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    if (err == ESP_OK) {
        *val = tmp;
    }
    return err;
}

esp_err_t bo_nvs_get_u8_or(nvs_handle_t h, const char* key, uint8_t* val)
{
    if (val == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    uint8_t tmp;
    esp_err_t err = nvs_get_u8(h, key, &tmp);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    if (err == ESP_OK) {
        *val = tmp;
    }
    return err;
}

esp_err_t bo_nvs_get_i16_or(nvs_handle_t h, const char* key, int16_t* val)
{
    if (val == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    int16_t tmp;
    esp_err_t err = nvs_get_i16(h, key, &tmp);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    if (err == ESP_OK) {
        *val = tmp;
    }
    return err;
}

esp_err_t bo_nvs_get_u16_or(nvs_handle_t h, const char* key, uint16_t* val)
{
    if (val == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    uint16_t tmp;
    esp_err_t err = nvs_get_u16(h, key, &tmp);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    if (err == ESP_OK) {
        *val = tmp;
    }
    return err;
}

esp_err_t bo_nvs_get_i32_or(nvs_handle_t h, const char* key, int32_t* val)
{
    if (val == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    int32_t tmp;
    esp_err_t err = nvs_get_i32(h, key, &tmp);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    if (err == ESP_OK) {
        *val = tmp;
    }
    return err;
}

esp_err_t bo_nvs_get_u32_or(nvs_handle_t h, const char* key, uint32_t* val)
{
    if (val == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    uint32_t tmp;
    esp_err_t err = nvs_get_u32(h, key, &tmp);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    if (err == ESP_OK) {
        *val = tmp;
    }
    return err;
}

esp_err_t bo_nvs_get_i64_or(nvs_handle_t h, const char* key, int64_t* val)
{
    if (val == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    int64_t tmp;
    esp_err_t err = nvs_get_i64(h, key, &tmp);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    if (err == ESP_OK) {
        *val = tmp;
    }
    return err;
}

esp_err_t bo_nvs_get_u64_or(nvs_handle_t h, const char* key, uint64_t* val)
{
    if (val == NULL) {
        return ESP_ERR_INVALID_ARG;
    }

    uint64_t tmp;
    esp_err_t err = nvs_get_u64(h, key, &tmp);
    if (err == ESP_ERR_NVS_NOT_FOUND) {
        return ESP_OK;
    }
    if (err == ESP_OK) {
        *val = tmp;
    }
    return err;
}

/**
 * \brief Clear user partition
 *
 */
esp_err_t bo_nvs_user_reset()
{
    //
    return nvs_flash_erase_partition(NVS_DEFAULT_PART_NAME);
}

void bo_nvs_auto_close(nvs_handle_t* handle)
{
    if (*handle != 0) {
        nvs_close(*handle);
        *handle = 0;
    }
}
