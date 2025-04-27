#include <string.h>
#include <time.h>
#include <errno.h>
#include <math.h>

#include <esp_system.h>
#include <esp_event.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <driver/ledc.h>
#include <esp_err.h>
#include <esp_log.h>
#include <nvs_flash.h>
#include <esp_rom_md5.h>

#include <borneo/common.h>
#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>

#include "lyfi-events.h"
#include "algo.h"
#include "led.h"

#define LED_NVS_NS "led"
#define LED_NVS_KEY_SCHEDULER_ENABLED "sch_en"
#define LED_NVS_KEY_MANUAL_COLOR "mcolor"
#define LED_NVS_KEY_SCHEDULER "sch"
#define LED_NVS_KEY_NIGHTLIGHT_DURATION "nld"
#define LED_NVS_KEY_CORRECTION_METHOD "corrmtd"
#define LED_NVS_KEY_PWM_FREQ "pwmfreq"
#define LED_NVS_KEY_LOC "loc"

static const struct led_user_settings LED_DEFAULT_SETTINGS = {
    .scheduler_enabled = 0,
    .nightlight_duration = 60 * 20,
    .manual_color = {
// From kconfig
#if CONFIG_LYFI_LED_CH0_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH1_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH2_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH3_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH4_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH5_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH6_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH7_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH8_ENABLED
        10,
#endif
#if CONFIG_LYFI_LED_CH9_ENABLED
        10,
#endif
    },
    .scheduler = { 0 },

    .loc = {
        .lat = NAN,
        .lng = NAN,
    },
};

int led_load_factory_settings(struct led_factory_settings* factory_settings)
{
    int rc;
    nvs_handle_t handle;
    rc = bo_nvs_factory_open(LED_NVS_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    rc = nvs_get_u16(handle, LED_NVS_KEY_PWM_FREQ, &factory_settings->pwm_freq);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        factory_settings->pwm_freq = CONFIG_LYFI_DEFAULT_PWM_FREQ;
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

int led_load_user_settings(struct led_user_settings* settings)
{
    int rc;
    size_t size;
    nvs_handle_t handle;
    rc = bo_nvs_user_open(LED_NVS_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    {
        rc = nvs_get_u8(handle, LED_NVS_KEY_SCHEDULER_ENABLED, &settings->scheduler_enabled);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->scheduler_enabled = LED_DEFAULT_SETTINGS.scheduler_enabled;
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
    }

    {
        rc = nvs_get_u16(handle, LED_NVS_KEY_NIGHTLIGHT_DURATION, &settings->nightlight_duration);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->nightlight_duration = LED_DEFAULT_SETTINGS.nightlight_duration;
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
    }

    {
        size = sizeof(struct led_scheduler);
        rc = nvs_get_blob(handle, LED_NVS_KEY_SCHEDULER, &settings->scheduler, &size);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            memcpy(&settings->scheduler, &LED_DEFAULT_SETTINGS.scheduler, sizeof(struct led_scheduler));
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
    }

    {
        size = sizeof(led_color_t);
        rc = nvs_get_blob(handle, LED_NVS_KEY_MANUAL_COLOR, &settings->manual_color, &size);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            memcpy(&settings->manual_color, &LED_DEFAULT_SETTINGS.manual_color, sizeof(led_color_t));
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
    }

    {
        rc = nvs_get_u8(handle, LED_NVS_KEY_CORRECTION_METHOD, &settings->correction_method);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->correction_method = LED_DEFAULT_SETTINGS.correction_method;
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
    }

    {
        double loc_blob[2];
        size = sizeof(loc_blob);
        rc = nvs_get_blob(handle, LED_NVS_KEY_LOC, loc_blob, &size);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->loc = LED_DEFAULT_SETTINGS.loc;
            rc = 0;
        }
        if (rc) {
            goto _EXIT_CLOSE;
        }
        settings->loc.lat = loc_blob[0];
        settings->loc.lng = loc_blob[1];
    }

    // TODO
    // Loading the brightness and power settings...
#ifdef CONFIG_LYFI_STANDALONE_CONTROLLER
#endif // CONFIG_LYFI_STANDALONE_CONTROLLER

_EXIT_CLOSE:
    bo_nvs_close(handle);
_EXIT_WITHOUT_CLOSE:
    return rc;
}

int led_save_user_settings(const struct led_user_settings* settings)
{
    int rc;
    nvs_handle_t handle;
    rc = bo_nvs_user_open(LED_NVS_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    rc = nvs_set_u8(handle, LED_NVS_KEY_SCHEDULER_ENABLED, settings->scheduler_enabled);
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_u16(handle, LED_NVS_KEY_NIGHTLIGHT_DURATION, settings->nightlight_duration);
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_u8(handle, LED_NVS_KEY_CORRECTION_METHOD, settings->correction_method);
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_blob(handle, LED_NVS_KEY_SCHEDULER, &settings->scheduler, sizeof(struct led_scheduler));
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_set_blob(handle, LED_NVS_KEY_MANUAL_COLOR, settings->manual_color, sizeof(led_color_t));
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_commit(handle);

_EXIT_CLOSE:
    bo_nvs_close(handle);
_EXIT_WITHOUT_CLOSE:
    return rc;
}
