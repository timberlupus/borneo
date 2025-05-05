#include <stdlib.h>
#include <string.h>

#include <sys/errno.h>

#include <esp_event.h>
#include <esp_log.h>
#include <esp_system.h>
#include <esp_timer.h>
#include <esp_wifi.h>
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <nvs_flash.h>
#include <esp_netif.h>

#include <borneo/common.h>
#include <borneo/system.h>
#include <borneo/wifi.h>

#if CONFIG_BT_BLE_ENABLED
#include "./blufi.h"
#else
#include "./sc.h"
#endif

#define SSID_MAX_LEN 32
#define SHORT_SHUTDOWN_PERIOD 30
#define NVS_NS "borneo.wifi"
#define NVS_COUNT_KEY "shutdown-count"
#define TAG "wifi"
#define WIFI_RECONNECT_INTERVAL_MS 5000

static int bo_wifi_start();
static int _update_nvs_early(int32_t* shutdown_count);
static int _update_nvs_reset();
static void _timer_callback(void* args);
static void _wifi_reconnect_callback(void* arg);

static esp_timer_handle_t _wifi_reconnect_timer = NULL;
static esp_timer_handle_t _shutdown_checking_timer = NULL;
static bool _has_ssid();

static void wifi_events_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static void system_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data);

static bool s_configurated = false;
static portMUX_TYPE s_status_lock = portMUX_INITIALIZER_UNLOCKED;

int bo_wifi_init()
{
    ESP_LOGI(TAG, "Initializing Borneo WiFi sub-system...");
    esp_netif_t* sta_netif = esp_netif_create_default_wifi_sta();
    if (sta_netif == NULL) {
        return -1;
    }

    wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
    BO_TRY(esp_wifi_init(&cfg));
    BO_TRY(esp_wifi_set_mode(WIFI_MODE_STA));
    BO_TRY(esp_wifi_set_ps(WIFI_PS_NONE));
    BO_TRY(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_events_handler, NULL));
    BO_TRY(esp_event_handler_register(BO_SYSTEM_EVENTS, ESP_EVENT_ANY_ID, &system_events_handler, NULL));

    return bo_wifi_start();
}

int bo_wifi_start()
{
    BO_TRY(esp_wifi_start());

    // Try to connect the AP
    if (!_has_ssid()) {
        ESP_LOGI(TAG, "There is no saved WiFi configuration.");

#if CONFIG_BT_BLE_BLUFI_ENABLE
        BO_TRY(bo_wifi_blufi_init());
        BO_TRY(bo_wifi_blufi_start());
#else
        BO_TRY(bo_wifi_sc_init());
        BO_TRY(bo_wifi_sc_start());
#endif
    }
    else {
        BO_TRY(esp_wifi_connect());

        int32_t shutdown_count = 0;
        BO_TRY(_update_nvs_early(&shutdown_count));

        if (shutdown_count > 3) {
            ESP_LOGI(TAG, "Shutdown counter: %ld", shutdown_count);
            BO_TRY(_update_nvs_reset());
            BO_TRY(bo_wifi_forget());
            vTaskDelay(pdMS_TO_TICKS(1000));
            esp_restart();
        }

        const esp_timer_create_args_t timer_args = {
            .callback = &_timer_callback,
            .name = "settings_sync_timer",
        };

        BO_TRY(esp_timer_create(&timer_args, &_shutdown_checking_timer));
        BO_TRY(esp_timer_start_once(_shutdown_checking_timer, SHORT_SHUTDOWN_PERIOD * 1000000));
    }

    ESP_LOGI(TAG, "WiFi sub-system has been initialized successfully.");
    return 0;
}

int bo_wifi_forget()
{
    ESP_LOGI(TAG, "Start to restore WiFi config...");

    int error = esp_wifi_restore();
    if (error == ESP_ERR_WIFI_NOT_INIT) {
        wifi_init_config_t cfg = WIFI_INIT_CONFIG_DEFAULT();
        error = esp_wifi_init(&cfg);
        if (error != 0) {
            return error;
        }

        BO_TRY(esp_wifi_restore());
    }
    else if (error != 0) {
        return error;
    }
    ESP_LOGI(TAG, "WiFi info has been restored.");
    return 0;
}

static void wifi_events_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    switch (event_id) {

    case WIFI_EVENT_STA_START: {
        ESP_LOGI(TAG, "WiFi station mode started.");
    } break;

    case WIFI_EVENT_STA_STOP: {
        ESP_LOGI(TAG, "WiFi station mode stopped.");
    } break;

    case WIFI_EVENT_STA_DISCONNECTED: {
        wifi_config_t wifi_config = { 0 };
        int rc = esp_wifi_get_config(ESP_IF_WIFI_STA, &wifi_config);
        if (rc == ESP_OK) {
            const char* saved_ssid = (const char*)wifi_config.sta.ssid;
            if (strnlen(saved_ssid, MAX_SSID_LEN) > 0) {
                int rc = esp_wifi_connect();
                if (rc != ESP_OK) {
                    ESP_LOGE(TAG, "Failed to connect WiFi AP(SSID=%s). errno=%d. Attempting to reconnect...",
                             saved_ssid, rc);
                    // Start the reconnect timer
                    if (_wifi_reconnect_timer == NULL) {
                        esp_timer_create_args_t timer_args = {
                            .callback = &_wifi_reconnect_callback,
                            .arg = NULL,
                            .name = "wifi_reconnect",
                        };
                        BO_MUST(esp_timer_create(&timer_args, &_wifi_reconnect_timer));
                        BO_MUST(esp_timer_start_once(_wifi_reconnect_timer, WIFI_RECONNECT_INTERVAL_MS * 1000));
                    }
                }
            }
            else {
                ESP_LOGE(TAG, "Something wrong here. We're disconnected but there is no saved WiFi configuration.");
            }
        }
    } break;

    case WIFI_EVENT_STA_CONNECTED: {
        if (_wifi_reconnect_timer != NULL) {
            BO_MUST(esp_timer_stop(_wifi_reconnect_timer));
            BO_MUST(esp_timer_delete(_wifi_reconnect_timer));
            _wifi_reconnect_timer = NULL;
        }
        ESP_LOGI(TAG, "WiFi connected successfully.");
    } break;

    case WIFI_EVENT_HOME_CHANNEL_CHANGE:
        break;

    default: {
        ESP_LOGI(TAG, "Unknown WiFi event. event_base=%s, event_id=%ld", event_base, event_id);
    } break;

    } // switch
}

int bo_wifi_get_rssi(int* rssi)
{
    if (rssi == NULL) {
        return -EINVAL;
    }
    BO_TRY(esp_wifi_sta_get_rssi(rssi));
    return 0;
}

void _timer_callback(void* args) { _update_nvs_reset(); }

int _update_nvs_early(int32_t* shutdown_count)
{
    nvs_handle_t nvs_handle;
    BO_TRY(nvs_open(NVS_NS, NVS_READWRITE, &nvs_handle));

    int32_t counter = 1;
    int err = nvs_get_i32(nvs_handle, NVS_COUNT_KEY, &counter);
    if (err != ESP_OK && err != ESP_ERR_NVS_NOT_FOUND) {
        goto EXIT_AND_CLOSE;
    }

    if (err == ESP_ERR_NVS_NOT_FOUND) {
        err = nvs_set_i32(nvs_handle, NVS_COUNT_KEY, counter);
        if (err) {
            goto EXIT_AND_CLOSE;
        }
    }
    else {
        // Update booting times
        counter++;
        err = nvs_set_i32(nvs_handle, NVS_COUNT_KEY, counter);
        if (err) {
            goto EXIT_AND_CLOSE;
        }
    }
    *shutdown_count = counter;
    ESP_LOGI(TAG, "Shutdown counter=%ld", counter);

EXIT_AND_CLOSE:
    nvs_close(nvs_handle);
    return err;
}

int _update_nvs_reset()
{
    ESP_LOGI(TAG, "Reset the shutdown counter");

    nvs_handle_t nvs_handle;
    BO_TRY(nvs_open(NVS_NS, NVS_READWRITE, &nvs_handle));

    int32_t shutdown_count = 0;
    int err = nvs_set_i32(nvs_handle, NVS_COUNT_KEY, shutdown_count);
    if (err != ESP_OK) {
        goto EXIT_AND_CLOSE;
    }

EXIT_AND_CLOSE:
    nvs_close(nvs_handle);
    return err;
}

void _wifi_reconnect_callback(void* arg)
{
    ESP_LOGI(TAG, "Checking Wi-Fi connection...");
    if (_has_ssid()) {
        ESP_LOGI(TAG, "Not connected to AP. Reconnecting...");
        int rc = esp_wifi_connect();
        if (rc) {
            ESP_LOGE(TAG, "Failed to connect to AP.");
        }
    }
    else {
        ESP_LOGI(TAG, "SSID is invalid or already connected to AP.");
    }
}

bool _has_ssid()
{
    wifi_config_t wifi_config = { 0 };
    int rc = esp_wifi_get_config(ESP_IF_WIFI_STA, &wifi_config);
    if (rc == ESP_OK) {
        const char* saved_ssid = (const char*)wifi_config.sta.ssid;
        return (strnlen(saved_ssid, MAX_SSID_LEN) > 0);
    }
    else {
        return false;
    }
}

void system_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data)
{
    switch (event_id) {
    case BO_EVENT_REBOOTING: {
        esp_wifi_disconnect();
    } break;

    default:
        break;
    }
}

bool bo_wifi_configurated()
{
    bool configurated;
    portENTER_CRITICAL(&s_status_lock);
    configurated = s_configurated;
    portEXIT_CRITICAL(&s_status_lock);
    return configurated;
}