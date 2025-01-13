
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
    return nvs_open_from_partition(NVS_FACTORY_PART_NAME, name, open_mode, out_handle);
}

esp_err_t bo_nvs_user_open(const char* name, nvs_open_mode_t open_mode, nvs_handle_t* out_handle)
{
    return nvs_open_from_partition(NVS_DEFAULT_PART_NAME, name, open_mode, out_handle);
}

void bo_nvs_close(nvs_handle_t handle) { nvs_close(handle); }

/**
 * \brief Clear user partition
 *
 */
esp_err_t bo_nvs_user_reset()
{
    //
    return nvs_flash_erase_partition(NVS_DEFAULT_PART_NAME);
}
