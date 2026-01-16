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

#if CONFIG_BORNEO_PROV_METHOD_NP
#include "np.h"
#elif CONFIG_BORNEO_PROV_METHOD_SC
#include "sc.h"
#endif

#define SSID_MAX_LEN 32
#define SHORT_SHUTDOWN_PERIOD 30
#define NVS_NS "borneo.wifi"
#define NVS_COUNT_KEY "shutdown-count"
#define TAG "wifi"
#define WIFI_RECONNECT_INTERVAL_MS 5000
#define RECONNECT_ATTEMPTS_MAX 5

static int bo_wifi_start();
static int bo_wifi_enter_provisioning();
static int _update_nvs_early(int32_t* shutdown_count);
static int _update_nvs_reset();
static void _timer_callback(void* args);
static void _wifi_reconnect_callback(void* arg);
static int _attempt_wifi_reconnect();
static void _shutdown_timer_cleanup(); // Forward declaration for shutdown timer cleanup helper

static esp_timer_handle_t _wifi_reconnect_timer = NULL;
static esp_timer_handle_t _shutdown_checking_timer = NULL;
static bool _has_ssid();
static int s_reconnect_attempts = 0;

static void wifi_events_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static void system_events_handler(void* handler_args, esp_event_base_t base, int32_t event_id, void* event_data);
static void bo_wifi_events_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static void wifi_on_disconnected(void* event_data);

typedef enum {
    WIFI_STATE_DISCONNECTED = 0,
    WIFI_STATE_CONNECTING,
    WIFI_STATE_PROVISIONING,
    WIFI_STATE_CONNECTED,
} bo_wifi_state_t;

static bo_wifi_state_t s_wifi_state = WIFI_STATE_DISCONNECTED;
static portMUX_TYPE s_status_lock = portMUX_INITIALIZER_UNLOCKED;

ESP_EVENT_DEFINE_BASE(BO_WIFI_EVENTS);

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
    BO_TRY(esp_event_handler_register(BO_WIFI_EVENTS, ESP_EVENT_ANY_ID, &bo_wifi_events_handler,
                                      NULL)); // 添加BO_WIFI_EVENTS注册
    BO_TRY(esp_event_handler_register(BO_SYSTEM_EVENTS, ESP_EVENT_ANY_ID, &system_events_handler, NULL));

    return bo_wifi_start();
}

int bo_wifi_start()
{
    BO_TRY(esp_wifi_start());

    // Try to connect the AP
    if (!_has_ssid()) {
        ESP_LOGI(TAG, "There is no saved WiFi configuration.");
        portENTER_CRITICAL(&s_status_lock);
        s_wifi_state = WIFI_STATE_PROVISIONING;
        portEXIT_CRITICAL(&s_status_lock);

#if CONFIG_BORNEO_PROV_METHOD_NP
        BO_TRY(bo_wifi_np_init());
        BO_TRY(bo_wifi_np_start());
#elif CONFIG_BORNEO_PROV_METHOD_SC
        BO_TRY(bo_wifi_sc_init());
        BO_TRY(bo_wifi_sc_start());
#endif
    }
    else {
        portENTER_CRITICAL(&s_status_lock);
        s_wifi_state = WIFI_STATE_CONNECTING;
        portEXIT_CRITICAL(&s_status_lock);
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

        _shutdown_timer_cleanup();
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

    // Enter provisioning mode
    BO_TRY(bo_wifi_enter_provisioning());

    ESP_LOGI(TAG, "WiFi info has been restored and provisioning started.");
    return 0;
}

/**
 * @brief Enter WiFi provisioning mode without restarting WiFi
 * Assumes WiFi is already running from bo_wifi_start()
 * @return 0 on success, error code on failure
 */
static int bo_wifi_enter_provisioning()
{
    // Set state to provisioning
    portENTER_CRITICAL(&s_status_lock);
    s_wifi_state = WIFI_STATE_PROVISIONING;
    s_reconnect_attempts = 0; // Reset reconnect attempts
    portEXIT_CRITICAL(&s_status_lock);

    // Clean up any pending reconnect timer
    if (_wifi_reconnect_timer != NULL) {
        esp_timer_stop(_wifi_reconnect_timer);
        esp_timer_delete(_wifi_reconnect_timer);
        _wifi_reconnect_timer = NULL;
    }

    // Clean up shutdown timer to avoid stale callbacks during provisioning
    _shutdown_timer_cleanup();

#if CONFIG_BORNEO_PROV_METHOD_NP
    BO_TRY(bo_wifi_np_init());
    BO_TRY(bo_wifi_np_start());
#elif CONFIG_BORNEO_PROV_METHOD_SC
    BO_TRY(bo_wifi_sc_init());
    BO_TRY(bo_wifi_sc_start());
#endif

    return 0;
}

/**
 * @brief Attempt to reconnect to WiFi with retry logic
 * @return 0 on success, -1 if max attempts reached or no SSID configured
 */
static int _attempt_wifi_reconnect()
{
    if (!_has_ssid()) {
        ESP_LOGI(TAG, "No SSID configured, cannot reconnect.");
        return -1;
    }

    portENTER_CRITICAL(&s_status_lock);
    bool should_reconnect = s_reconnect_attempts < RECONNECT_ATTEMPTS_MAX;
    if (should_reconnect) {
        s_reconnect_attempts++;
    }
    int attempts = s_reconnect_attempts;
    portEXIT_CRITICAL(&s_status_lock);

    if (!should_reconnect) {
        ESP_LOGW(TAG, "Maximum reconnect attempts (%d) reached. Stopping reconnection.", RECONNECT_ATTEMPTS_MAX);
        return -1;
    }

    ESP_LOGI(TAG, "Attempting to reconnect (attempt %d/%d)...", attempts, RECONNECT_ATTEMPTS_MAX);
    int rc = esp_wifi_connect();
    if (rc != ESP_OK) {
        ESP_LOGE(TAG, "Failed to initiate WiFi connection. errno=%d. Will retry later...", rc);
        return -1;
    }

    portENTER_CRITICAL(&s_status_lock);
    s_wifi_state = WIFI_STATE_CONNECTING;
    portEXIT_CRITICAL(&s_status_lock);
    return 0;
}

/**
 * @brief Determine whether WiFi configuration should be cleared
 *
 * @param reason WiFi disconnection reason
 * @return true Configuration should be cleared and re-provisioning is needed
 * @return false Configuration can be kept and reconnection should be attempted
 */
static bool should_clear_wifi_config(wifi_err_reason_t reason)
{
    switch (reason) {
    // Password/authentication errors - need to clear
    case WIFI_REASON_AUTH_FAIL:
    case WIFI_REASON_4WAY_HANDSHAKE_TIMEOUT:
    case WIFI_REASON_HANDSHAKE_TIMEOUT:
    case WIFI_REASON_802_1X_AUTH_FAILED:
    case WIFI_REASON_MIC_FAILURE:
    case WIFI_REASON_INVALID_PMKID:

    // Cipher suite incompatibility - need to clear
    case WIFI_REASON_GROUP_CIPHER_INVALID:
    case WIFI_REASON_PAIRWISE_CIPHER_INVALID:
    case WIFI_REASON_CIPHER_SUITE_REJECTED:
    case WIFI_REASON_BAD_CIPHER_OR_AKM:
    case WIFI_REASON_UNSUPP_RSN_IE_VERSION:
    case WIFI_REASON_INVALID_RSN_IE_CAP:
    case WIFI_REASON_NO_AP_FOUND_W_COMPATIBLE_SECURITY:
    case WIFI_REASON_NO_AP_FOUND_IN_AUTHMODE_THRESHOLD:
        return true;

    default:
        return false;
    }
}

static void wifi_on_disconnected(void* event_data)
{
    portENTER_CRITICAL(&s_status_lock);
    s_wifi_state = WIFI_STATE_DISCONNECTED;
    portEXIT_CRITICAL(&s_status_lock);
    wifi_event_sta_disconnected_t* event = (wifi_event_sta_disconnected_t*)event_data;
    uint8_t reason = event->reason;

    ESP_LOGW(TAG, "WiFi disconnected. Reason: %d", reason);

    // Check if configuration should be cleared
    if (should_clear_wifi_config(reason)) {
        ESP_LOGW(TAG,
                 "WiFi disconnected due to auth/security issue (reason=%d). Clearing saved configuration and entering "
                 "provisioning mode.",
                 reason);
        if (_wifi_reconnect_timer != NULL) {
            esp_timer_stop(_wifi_reconnect_timer);
            esp_timer_delete(_wifi_reconnect_timer);
            _wifi_reconnect_timer = NULL;
        }
        bo_wifi_forget();
        return;
    }

    // Stop shutdown timer once we are disconnected to avoid unnecessary reset callback
    _shutdown_timer_cleanup();

    // Attempt to reconnect
    int rc = _attempt_wifi_reconnect();
    if (rc != 0) {
        // Max attempts reached or no SSID, start timer for later retry
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

static void wifi_events_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    switch (event_id) {
    case WIFI_EVENT_SCAN_DONE: {
        ESP_LOGI(TAG, "WiFi scan done.");
    } break;

    case WIFI_EVENT_STA_START: {
        ESP_LOGI(TAG, "WiFi station mode started.");
    } break;

    case WIFI_EVENT_STA_STOP: {
        ESP_LOGI(TAG, "WiFi station mode stopped.");
    } break;

    case WIFI_EVENT_STA_DISCONNECTED: {
        wifi_on_disconnected(event_data);
    } break;

    case WIFI_EVENT_STA_CONNECTED: {
        portENTER_CRITICAL(&s_status_lock);
        s_wifi_state = WIFI_STATE_CONNECTED;
        s_reconnect_attempts = 0; // Reset reconnect attempts on successful connection
        portEXIT_CRITICAL(&s_status_lock);
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

static void bo_wifi_events_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    switch (event_id) {
    case BO_EVENT_WIFI_PROVISIONING_START: {
        ESP_LOGI(TAG, "Provisioning started.");
        esp_event_handler_unregister(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_events_handler);
        portENTER_CRITICAL(&s_status_lock);
        s_wifi_state = WIFI_STATE_PROVISIONING;
        portEXIT_CRITICAL(&s_status_lock);
        break;
    }
    case BO_EVENT_WIFI_PROVISIONING_SUCCESS: {
        ESP_LOGI(TAG, "Provisioning successful.");
        BO_MUST(esp_event_handler_register(WIFI_EVENT, ESP_EVENT_ANY_ID, &wifi_events_handler, NULL));
        portENTER_CRITICAL(&s_status_lock);
        s_wifi_state = WIFI_STATE_CONNECTING;
        portEXIT_CRITICAL(&s_status_lock);
        if (_has_ssid()) {
            BO_MUST(esp_wifi_connect());
        }
        break;
    }
    case BO_EVENT_WIFI_PROVISIONING_FAIL: {
        ESP_LOGE(TAG, "Provisioning failed.");
        break;
    }
    default:
        break;
    }
}

int bo_wifi_get_rssi(int* rssi)
{
    if (rssi == NULL) {
        return -EINVAL;
    }
    BO_TRY(esp_wifi_sta_get_rssi(rssi));
    return 0;
}

static void _shutdown_timer_cleanup()
{
    if (_shutdown_checking_timer != NULL) {
        esp_timer_stop(_shutdown_checking_timer);
        esp_timer_delete(_shutdown_checking_timer);
        _shutdown_checking_timer = NULL;
    }
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
    int rc = _attempt_wifi_reconnect();
    if (rc != 0) {
        // Max attempts reached, clean up timer
        if (_wifi_reconnect_timer != NULL) {
            BO_MUST(esp_timer_stop(_wifi_reconnect_timer));
            BO_MUST(esp_timer_delete(_wifi_reconnect_timer));
            _wifi_reconnect_timer = NULL;
        }
    }
    else {
        // Reconnect initiated, restart timer for next check if needed
        BO_MUST(esp_timer_start_once(_wifi_reconnect_timer, WIFI_RECONNECT_INTERVAL_MS * 1000));
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
    bo_wifi_state_t state;
    portENTER_CRITICAL(&s_status_lock);
    state = s_wifi_state;
    portEXIT_CRITICAL(&s_status_lock);
    return (state == WIFI_STATE_CONNECTED);
}