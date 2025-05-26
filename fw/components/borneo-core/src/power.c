#include <string.h>
#include <sys/time.h>
#include <errno.h>

#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>

#include <esp_timer.h>
#include <esp_attr.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_system.h>
#include <nvs_flash.h>

#include <borneo/system.h>
#include <borneo/common.h>
#include <borneo/power.h>
#include <borneo/nvs.h>

struct power_settings {
    uint8_t behavior;
    uint8_t last_state;
};

struct power_state {
    bool is_power_on;
};

static int load_settings();
static int update_settings();

static struct power_state _state;
static struct power_settings _settings;

#define POWER_NVS_NS "power"
#define POWER_NVS_KEY_LAST_STATE "last"
#define POWER_NVS_KEY_BEHAVIOR "behavior"

#define TAG "power"

int bo_power_init()
{
    ESP_LOGI(TAG, "Initializing power subsystem...");
    memset(&_state, 0, sizeof(_state));

    BO_TRY(load_settings());

    switch (_settings.behavior) {
    case POWER_AUTO_POWER_ON:
        _state.is_power_on = true;
        break;

    case POWER_MAINTAIN_POWER_OFF:
        _state.is_power_on = false;
        break;

    case POWER_LAST_POWER_STATE:
        _state.is_power_on = _settings.last_state;
        break;

    default:
        return -EINVAL;
    }

    ESP_LOGI(TAG, "Power subsystem initialization succeed.");
    return 0;
}

bool bo_power_is_on()
{
    //
    return _state.is_power_on;
}

int bo_power_on()
{
    if (_state.is_power_on) {
        return -EINVAL;
    }
    _state.is_power_on = true;
    _settings.last_state = true;
    BO_TRY(esp_event_post(BO_SYSTEM_EVENTS, BO_EVENT_POWER_ON, NULL, 0, portMAX_DELAY));
    BO_TRY(update_settings());
    return 0;
}

int bo_power_shutdown(uint32_t reason)
{
    _state.is_power_on = false;
    _settings.last_state = false;
    if (reason) {
        BO_TRY(esp_event_post(BO_SYSTEM_EVENTS, BO_EVENT_SHUTDOWN_FAULT, NULL, 0, portMAX_DELAY));
    }
    else {
        BO_TRY(esp_event_post(BO_SYSTEM_EVENTS, BO_EVENT_SHUTDOWN_SCHEDULED, NULL, 0, portMAX_DELAY));
    }
    bo_system_set_shutdown_reason(reason);
    if (reason == BO_SHUTDOWN_REASON_SCHEDULED) {
        BO_TRY(update_settings());
    }
    return 0;
}

uint8_t bo_power_get_behavior() { return _settings.behavior; }

int bo_power_set_behavior(uint8_t behavior)
{
    if (behavior >= POWER_INVALID_BEHAVIOR) {
        return -EINVAL;
    }
    _settings.behavior = behavior;
    BO_TRY(update_settings());
    return 0;
}

static int load_settings()
{
    int rc;
    nvs_handle_t handle;
    rc = bo_nvs_user_open(POWER_NVS_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    rc = nvs_get_u8(handle, POWER_NVS_KEY_BEHAVIOR, &_settings.behavior);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.behavior = POWER_LAST_POWER_STATE;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_get_u8(handle, POWER_NVS_KEY_LAST_STATE, &_settings.last_state);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.last_state = 1;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

_EXIT_CLOSE:
    bo_nvs_close(handle);
_EXIT_WITHOUT_CLOSE:
    return rc;
}

static int update_settings()
{
    int rc;
    nvs_handle_t handle;
    rc = bo_nvs_user_open(POWER_NVS_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    rc = nvs_set_u8(handle, POWER_NVS_KEY_BEHAVIOR, _settings.behavior);
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_u8(handle, POWER_NVS_KEY_LAST_STATE, _settings.last_state);
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_commit(handle);

_EXIT_CLOSE:
    bo_nvs_close(handle);
_EXIT_WITHOUT_CLOSE:
    return rc;
}
