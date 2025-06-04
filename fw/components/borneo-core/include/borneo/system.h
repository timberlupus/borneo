#pragma once

#include <esp_system.h>
#include <esp_event.h>

#include <borneo/common.h>
#include <drvfx/drvfx.h>

#ifdef __cplusplus
extern "C" {
#endif

#define BO_DEVICE_ID_LENGTH 32 ///< in bytes
#define BO_DEVICE_NAME_MAX 64
#define BO_DEVICE_MANUF_MAX 64
#define BO_DEVICE_MODEL_MAX 32

#define BO_MUST(expr)                                                                                                  \
    ({                                                                                                                 \
        int _rc = (expr);                                                                                              \
        if (unlikely(_rc != 0)) {                                                                                      \
            ESP_LOGE("borneo-system", "errcode=%d, %s(%d): ", _rc, __FUNCTION__, __LINE__);                            \
            bo_panic();                                                                                                \
        }                                                                                                              \
    })

#define BO_MUST_WITH(expr, log_tag, format, ...)                                                                       \
    ({                                                                                                                 \
        int _rc = (expr);                                                                                              \
        if (unlikely(_rc != 0)) {                                                                                      \
            ESP_LOGE(log_tag, "errcode=%d, %s(%d): " format, _rc, __FUNCTION__, __LINE__, ##__VA_ARGS__);              \
            bo_panic();                                                                                                \
        }                                                                                                              \
    })

#define BO_TRY(expression)                                                                                             \
    ({                                                                                                                 \
        int _rc = (expression);                                                                                        \
        if (unlikely(_rc != 0)) {                                                                                      \
            ESP_LOGE("borneo-system", "errcode=%d, %s(%d)", _rc, __FUNCTION__, __LINE__);                              \
            return _rc;                                                                                                \
        }                                                                                                              \
    })

#define BO_TRY_WITH(expression, log_tag, format, ...)                                                                  \
    ({                                                                                                                 \
        int _rc = (expression);                                                                                        \
        if (unlikely(_rc != 0)) {                                                                                      \
            ESP_LOGE(log_tag, "%s(%d): " format, __FUNCTION__, __LINE__, ##__VA_ARGS__);                               \
            return _rc;                                                                                                \
        }                                                                                                              \
    })

#define BO_SEM_AUTO_RELEASE(sem_expr)                                                                                  \
    __attribute__((cleanup(bo_sem_release))) SemaphoreHandle_t sem##_##__LINE__ = sem_expr

ESP_EVENT_DECLARE_BASE(BO_SYSTEM_EVENTS);

enum {
    BO_EVENT_INITIALIZING = 0, ///< Power-on start initialization
    BO_EVENT_READY, ///< Power-on initialization completed
    BO_EVENT_POWER_ON, ///< Soft power on
    BO_EVENT_REBOOTING, ///< Rebooting
    BO_EVENT_SHUTDOWN_SCHEDULED, ///< Scheduled a shutdown
    BO_EVENT_SHUTDOWN_FAULT, ///< Fault shutdown event
    BO_EVENT_TEMPERATURE_CHANGED, ///< Temperature changed event

    BO_EVENT_ENTRY_FACTORY_MODE, ///< Entry the Factory Mode

    BO_EVENT_FATAL_ERROR, ///< Fatal error occurred

    BO_EVENT_GEO_LOCATION_CHANGED, ///< Location changed
};

enum {
    BO_SHUTDOWN_REASON_SCHEDULED = 0,
    BO_SHUTDOWN_REASON_FATAL_ERROR = 0x00000001,
    BO_SHUTDOWN_REASON_OVERHEATED = 0x00000002,
    BO_SHUTDOWN_REASON_OVER_POWER = 0x00000003,

    BO_SHUTDOWN_REASON_UNKNOWN = 0xFFFFFFFF,
};

struct system_info {
    char name[BO_DEVICE_NAME_MAX];
    char model[BO_DEVICE_MODEL_MAX];
    char manuf[BO_DEVICE_MANUF_MAX];
    uint8_t id[BO_DEVICE_ID_LENGTH];
    char hex_id[(BO_DEVICE_ID_LENGTH * 2) + 1];
};

struct system_status {
    uint32_t state_flags;
    uint32_t shutdown_reason;
    uint64_t shutdown_timestamp;
    bool is_ready;
};

int bo_system_init();
void bo_system_set_ready();

const struct system_info* bo_system_get_info();

void bo_system_reboot_later(uint32_t delay_ms);

void bo_panic();

int bo_system_factory_reset();

int bo_system_set_name(const char* name);
int bo_system_set_model(const char* model);
int bo_system_set_manuf(const char* manuf);

uint32_t bo_system_get_shutdown_reason();
void bo_system_set_shutdown_reason(uint32_t reason);

uint64_t bo_system_get_shutdown_timestamp();

void bo_sem_release(SemaphoreHandle_t* sem);

bool bo_system_is_operable();
bool bo_system_connection_configurated();

#ifdef __cplusplus
}
#endif