#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <esp_system.h>
#include <esp_err.h>
#include <esp_log.h>
#include <nvs_flash.h>
#include <driver/ledc.h>
#include <nvs_flash.h>
#include <driver/gpio.h>

#include <borneo/system.h>
#include <borneo/common.h>
#include <borneo/power.h>
#include <borneo/power-meas.h>

#include "protect.h"

#if CONFIG_LYFI_PROTECTION_ENABLED

static int load_factory_settings();
static void protect_task();

#define PROTECT_NVS_NAMESPACE "protect"
#define NVS_KEY_ENABLED "en"
#define NVS_KEY_OPP_VALUE "opp"
#define TAG "protect"

struct bo_protect_settings {
    int32_t over_power_mw; // Over-Power Protection value
};

static struct bo_protect_settings _settings;

int bo_protect_init()
{
    ESP_LOGI(TAG, "Initializing over-power protection...");

    ESP_LOGI(TAG, "Loading factory settings...");
    BO_TRY(load_factory_settings());

    if (_settings.over_power_mw > 0) {
        xTaskCreate(protect_task, "protect_task", 2048, NULL, 5, NULL);
    }

    ESP_LOGI(TAG, "Over-power protection initialized");
    return 0;
}

int load_factory_settings()
{
    nvs_handle_t nvs_handle;
    int rc;
    BO_TRY(nvs_open(PROTECT_NVS_NAMESPACE, NVS_READWRITE, &nvs_handle));

    {
        rc = nvs_get_i32(nvs_handle, NVS_KEY_ENABLED, &_settings.over_power_mw);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            _settings.over_power_mw = CONFIG_LYFI_PROTECTION_OPP_DEFAULT_VALUE;
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
    }

_EXIT_CLOSE:
    nvs_close(nvs_handle);
    return rc;
}

void protect_task()
{
    for (;;) {
        int32_t power_mw;
        BO_MUST(bo_power_read(&power_mw));
        if (_settings.over_power_mw > 0 && power_mw > _settings.over_power_mw && bo_power_is_on()) {
            ESP_LOGE(TAG, "Over-power protection triggered! Shutdown in progress...");
            ESP_LOGE(TAG, "%ld mW >= %ld mW", power_mw, _settings.over_power_mw);
            BO_MUST(bo_power_shutdown(BO_SHUTDOWN_REASON_OVER_POWER));
        }
        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

#endif // CONFIG_LYFI_PROTECTION_ENABLED