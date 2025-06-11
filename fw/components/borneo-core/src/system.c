#include <stdlib.h>
#include <time.h>
#include <string.h>
#include <errno.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <esp_log.h>
#include <esp_system.h>
#include <esp_timer.h>
#include <esp_rom_md5.h>
#include <esp_event.h>
#include <esp_mac.h>
#include <nvs_flash.h>
#include <esp_flash.h>

#include <mbedtls/sha256.h>

#include <borneo/common.h>
#include <borneo/nvs.h>
#include <borneo/system.h>
#include <borneo/power.h>

#define TAG "system"
#define SYSTEM_NVS_NS "device"
#define SYSTEM_NVS_KEY_NAME "name"
#define SYSTEM_NVS_KEY_MODEL "model"
#define SYSTEM_NVS_KEY_MANUF "manuf"
#define SYSTEM_DEFAULT_MANUF "BorneoIoT"

enum state_flags_enum {
    STATE_FLAG_OPERABLE = 1,
    STATE_FLAG_CONNECTION_CONFIGURATED = 2,
};

static inline char to_hex_digit_upper(uint8_t val) { return (val < 10) ? ('0' + val) : ('A' + val - 10); }
static inline char to_hex_digit_lower(uint8_t val) { return (val < 10) ? ('0' + val) : ('a' + val - 10); }

static void _system_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static int load_factory_settings();

ESP_EVENT_DEFINE_BASE(BO_SYSTEM_EVENTS);

static portMUX_TYPE _status_lock = portMUX_INITIALIZER_UNLOCKED;

static struct system_info _sysinfo = { 0 };
static struct system_status _status = { 0 };

int bo_system_init()
{
    BO_TRY(load_factory_settings());

    // Make the device ID (EUI-64 from MAC)
    uint8_t mac[6];
    BO_TRY(esp_read_mac(mac, ESP_MAC_WIFI_STA));

    // EUI-64: insert 0xFFFE in the middle, flip U/L bit
    _sysinfo.id[0] = mac[0] ^ 0x02; // flip U/L bit
    _sysinfo.id[1] = mac[1];
    _sysinfo.id[2] = mac[2];
    _sysinfo.id[3] = 0xFF;
    _sysinfo.id[4] = 0xFE;
    _sysinfo.id[5] = mac[3];
    _sysinfo.id[6] = mac[4];
    _sysinfo.id[7] = mac[5];

    for (size_t i = 0; i < 8; ++i) {
        _sysinfo.hex_id[2 * i] = to_hex_digit_upper(_sysinfo.id[i] >> 4);
        _sysinfo.hex_id[2 * i + 1] = to_hex_digit_upper(_sysinfo.id[i] & 0xf);
    }
    _sysinfo.hex_id[16] = '\0';

    BO_TRY(esp_event_handler_register(BO_SYSTEM_EVENTS, ESP_EVENT_ANY_ID, &_system_event_handler, NULL));

    return 0;
}

void bo_system_set_ready()
{
    if (!_status.is_ready) {
        _status.is_ready = true;
        BO_MUST(esp_event_post(BO_SYSTEM_EVENTS, BO_EVENT_READY, NULL, 0, portMAX_DELAY));
    }
    else {
        bo_panic();
    }
}

void bo_panic()
{
    int rc = bo_power_shutdown(BO_SHUTDOWN_REASON_FATAL_ERROR);
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to do emergency shutdown.");
    }

    rc = esp_event_post(BO_SYSTEM_EVENTS, BO_EVENT_FATAL_ERROR, NULL, 0, pdMS_TO_TICKS(100));
    if (rc != 0) {
        ESP_LOGE(TAG, "Failed to post FATAL_ERROR message");
    }

    abort();
}

const struct system_info* bo_system_get_info() { return &_sysinfo; }

const struct system_status* bo_system_get_status() { return &_status; }

static void _reboot_callback();

void bo_system_reboot_later(uint32_t delay_ms)
{
    ESP_LOGI(TAG, "THIS DEVICE HAS BEEN SCHEDULED TO REBOOT AFTER %lu MILLISECONDS!!!", delay_ms);

    const esp_timer_create_args_t timer_args = {
        .callback = &_reboot_callback,
        .name = "reboot_timer",
    };
    esp_timer_handle_t* reboot_timer = (esp_timer_handle_t*)malloc(sizeof(esp_timer_handle_t));
    if (reboot_timer == NULL) {
        ESP_LOGE(TAG, "Failed to allocate reboot_timer.");
        return;
    }

    int rc = esp_timer_create(&timer_args, reboot_timer);
    if (rc) {
        free(reboot_timer);
        ESP_LOGE(TAG, "Failed to create reboot timer.");
        return;
    }

    rc = esp_timer_start_once(*reboot_timer, delay_ms * 1000);
    if (rc) {
        free(reboot_timer);
        ESP_LOGE(TAG, "Failed to start reboot timer.");
        return;
    }

    if (bo_power_is_on()) {
        BO_MUST(bo_power_shutdown(0));
        vTaskDelay(pdMS_TO_TICKS(1000));
    }

    BO_MUST(esp_event_post(BO_SYSTEM_EVENTS, BO_EVENT_REBOOTING, NULL, 0, portMAX_DELAY));
}

int bo_system_factory_reset()
{
    BO_TRY(bo_nvs_user_reset());

    return 0;
}

int bo_system_set_name(const char* name)
{
    if (name == NULL) {
        return -EINVAL;
    }

    nvs_handle_t nvs_handle;
    int rc;
    BO_TRY(bo_nvs_factory_open(SYSTEM_NVS_NS, NVS_READWRITE, &nvs_handle));

    rc = nvs_set_str(nvs_handle, SYSTEM_NVS_KEY_NAME, name);
    if (rc) {
        strncpy(_sysinfo.name, name, BO_DEVICE_NAME_MAX);
        rc = 0;
    }

    bo_nvs_close(nvs_handle);
    return 0;
}

int bo_system_set_model(const char* model)
{
    if (model == NULL) {
        return -EINVAL;
    }

    nvs_handle_t nvs_handle;
    int rc;
    BO_TRY(bo_nvs_factory_open(SYSTEM_NVS_NS, NVS_READWRITE, &nvs_handle));

    rc = nvs_set_str(nvs_handle, SYSTEM_NVS_KEY_MODEL, model);
    if (rc) {
        strncpy(_sysinfo.model, model, BO_DEVICE_MODEL_MAX);
        rc = 0;
    }

    bo_nvs_close(nvs_handle);
    return 0;
}

int bo_system_set_manuf(const char* manuf)
{
    if (manuf == NULL) {
        return -EINVAL;
    }

    nvs_handle_t nvs_handle;
    int rc;
    BO_TRY(bo_nvs_factory_open(SYSTEM_NVS_NS, NVS_READWRITE, &nvs_handle));

    rc = nvs_set_str(nvs_handle, SYSTEM_NVS_KEY_MANUF, manuf);
    if (rc) {
        strncpy(_sysinfo.manuf, manuf, BO_DEVICE_MANUF_MAX);
        rc = 0;
    }

    bo_nvs_close(nvs_handle);
    return 0;
}

uint32_t bo_system_get_shutdown_reason()
{
    uint32_t reason;
    portENTER_CRITICAL(&_status_lock);
    reason = _status.shutdown_reason;
    portEXIT_CRITICAL(&_status_lock);
    return reason;
}

void bo_system_set_shutdown_reason(uint32_t reason)
{
    portENTER_CRITICAL(&_status_lock);
    _status.shutdown_reason = reason;
    portEXIT_CRITICAL(&_status_lock);
}

uint64_t bo_system_get_shutdown_timestamp()
{
    uint64_t timestamp;
    portENTER_CRITICAL(&_status_lock);
    timestamp = _status.shutdown_timestamp;
    portEXIT_CRITICAL(&_status_lock);
    return timestamp;
}

void _reboot_callback() { esp_restart(); }

void _system_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    switch (event_id) {

    case BO_EVENT_READY: {
        ESP_LOGI(TAG, "Everything seems fine, the device is ready now.");
    } break;

    case BO_EVENT_POWER_ON: {
    } break;

    case BO_EVENT_SHUTDOWN_SCHEDULED:
    case BO_EVENT_SHUTDOWN_FAULT: {
        portENTER_CRITICAL(&_status_lock);
        time_t t = time(NULL);
        _status.shutdown_timestamp = t;
        portEXIT_CRITICAL(&_status_lock);
    } break;

    case BO_EVENT_FATAL_ERROR: {
    } break;

    default:
        break;
    }
}

int load_factory_settings()
{
    nvs_handle_t nvs_handle;
    int rc;
    size_t len;
    BO_TRY(bo_nvs_factory_open(SYSTEM_NVS_NS, NVS_READWRITE, &nvs_handle));

    len = BO_DEVICE_NAME_MAX;
    rc = nvs_get_str(nvs_handle, SYSTEM_NVS_KEY_NAME, _sysinfo.name, &len);
    if (rc) {
        strncpy(_sysinfo.name, CONFIG_BORNEO_DEVICE_NAME_DEFAULT, BO_DEVICE_NAME_MAX);
        rc = 0;
    }

    len = BO_DEVICE_MODEL_MAX;
    rc = nvs_get_str(nvs_handle, SYSTEM_NVS_KEY_MODEL, _sysinfo.model, &len);
    if (rc) {
        strncpy(_sysinfo.model, CONFIG_BORNEO_BOARD_NAME, BO_DEVICE_MODEL_MAX);
        rc = 0;
    }

    len = BO_DEVICE_MANUF_MAX;
    rc = nvs_get_str(nvs_handle, SYSTEM_NVS_KEY_MANUF, _sysinfo.manuf, &len);
    if (rc) {
        strncpy(_sysinfo.manuf, SYSTEM_DEFAULT_MANUF, BO_DEVICE_MANUF_MAX);
        rc = 0;
    }

    bo_nvs_close(nvs_handle);
    return 0;
}

bool bo_system_is_operable()
{
    bool result;
    portENTER_CRITICAL(&_status_lock);
    result = _status.state_flags & STATE_FLAG_OPERABLE;
    portEXIT_CRITICAL(&_status_lock);
    return result;
}

bool bo_system_connection_configurated()
{
    bool result;
    portENTER_CRITICAL(&_status_lock);
    result = _status.state_flags & STATE_FLAG_CONNECTION_CONFIGURATED;
    portEXIT_CRITICAL(&_status_lock);
    return result;
}

void bo_sem_release(SemaphoreHandle_t* sem)
{
    if (*sem) {
        xSemaphoreGive(*sem);
        *sem = NULL;
    }
}
