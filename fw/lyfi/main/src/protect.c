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

#include "thermal.h"
#include "protect.h"
#include "fan.h"

#if CONFIG_LYFI_PROTECTION_ENABLED

static int load_factory_settings();
static void protect_task();

#define PROTECT_NVS_NAMESPACE "protect"
#define NVS_KEY_ENABLED "en"
#define NVS_KEY_OPP_VALUE "opp"
#define NVS_KEY_OVERHEATED_TEMP "ohtemp"

#define OVERHEATED_TEMP_COUNT_MAX 3
#define PROTECT_OVERHEATED_TEMP_DEFAULT 65

#define TAG "protect"

struct bo_protect_settings {

#if CONFIG_LYFI_PROTECTION_OVER_POWER_ENABLED
    int32_t over_power_mw; // Over-Power Protection value
#endif // CONFIG_LYFI_PROTECTION_OVER_POWER_ENABLED

#if CONFIG_LYFI_PROTECTION_OVER_HEATED_ENABLED
    uint8_t overheated_temp; // Overheated temperature threshold
#endif // CONFIG_LYFI_PROTECTION_OVER_HEATED_ENABLED
};

struct bo_protect_status {

#if CONFIG_LYFI_PROTECTION_OVER_HEATED_ENABLED
    volatile int overheated_count; // Count of overheated events
#endif // CONFIG_LYFI_PROTECTION_OVER_HEATED_ENABLED
};

static struct bo_protect_status _protect = { 0 };
static struct bo_protect_settings _settings = { 0 };

int bo_protect_init()
{
    ESP_LOGI(TAG, "Initializing over-power protection...");

    ESP_LOGI(TAG, "Loading factory settings...");
    BO_TRY(load_factory_settings());

    xTaskCreate(&protect_task, "protect_task", 2048, NULL, 5, NULL);

    ESP_LOGI(TAG, "Over-power protection initialized");
    return 0;
}

uint8_t bo_protect_get_overheated_temp() { return _settings.overheated_temp; }

int load_factory_settings()
{
    nvs_handle_t nvs_handle;
    int rc;
    BO_TRY(nvs_open(PROTECT_NVS_NAMESPACE, NVS_READWRITE, &nvs_handle));

#if CONFIG_LYFI_PROTECTION_OVER_POWER_ENABLED
    {
        rc = nvs_get_i32(nvs_handle, NVS_KEY_ENABLED, &_settings.over_power_mw);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            _settings.over_power_mw = CONFIG_LYFI_PROTECTION_OVER_POWER_DEFAULT_VALUE;
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
    }
#endif // CONFIG_LYFI_PROTECTION_OVER_POWER_ENABLED

#if CONFIG_LYFI_PROTECTION_OVER_HEATED_ENABLED
    {
        rc = nvs_get_u8(nvs_handle, NVS_KEY_OVERHEATED_TEMP, &_settings.overheated_temp);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            _settings.overheated_temp = PROTECT_OVERHEATED_TEMP_DEFAULT;
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
    }
#endif // CONFIG_LYFI_PROTECTION_OVER_HEATED_ENABLED

_EXIT_CLOSE:
    nvs_close(nvs_handle);
    return rc;
}

void protect_task()
{
    for (;;) {
        if (bo_power_is_on()) {

#if CONFIG_LYFI_PROTECTION_OVER_POWER_ENABLED
            static int power_read_fail_count = 0;
            int32_t power_mw;
            int ret = bo_power_read(&power_mw);
            if (ret != 0) {
                power_read_fail_count++;
                if (power_read_fail_count >= 5) {
                    ESP_LOGE(TAG, "bo_power_read failed 5 times, panic!");
                    bo_panic();
                }
            }
            else {
                power_read_fail_count = 0;
                if (_settings.over_power_mw > 0 && power_mw > _settings.over_power_mw) {
                    ESP_LOGE(TAG, "Over-power protection triggered! Shutdown in progress...");
                    ESP_LOGE(TAG, "%ld mW >= %ld mW", power_mw, _settings.over_power_mw);
                    BO_MUST(bo_power_shutdown(BO_SHUTDOWN_REASON_OVER_POWER));
                }
            }
#endif // CONFIG_LYFI_PROTECTION_OVER_POWER_ENABLED

#if CONFIG_LYFI_PROTECTION_OVER_HEATED_ENABLED
            // Continuous detection of high temperatures multiple times will trigger an emergency shutdown of the
            // lights.
            int current_temp = thermal_get_current_temp();
            if (current_temp >= _settings.overheated_temp) {
                _protect.overheated_count++;
                ESP_LOGW(TAG, "[%u/%u] Too hot!", _protect.overheated_count, OVERHEATED_TEMP_COUNT_MAX);
                if (_protect.overheated_count > OVERHEATED_TEMP_COUNT_MAX) {
                    fan_set_power(100);
                    ESP_LOGW(TAG, "Over temperature(temp=%d, set=%u)! shuting down...", current_temp,
                             _settings.overheated_temp);
                    bo_power_shutdown(BO_SHUTDOWN_REASON_OVERHEATED);
                    _protect.overheated_count = 0;
                    return;
                }
            }
            else {
                _protect.overheated_count = 0;
            }
#endif // CONFIG_LYFI_PROTECTION_OVER_HEATED_ENABLED
        }

        vTaskDelay(pdMS_TO_TICKS(1000));
    }
}

#endif // CONFIG_LYFI_PROTECTION_ENABLED