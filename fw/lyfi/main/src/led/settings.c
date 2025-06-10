#include <string.h>
#include <time.h>
#include <errno.h>
#include <math.h>

#include <esp_system.h>
#include <esp_event.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/semphr.h>
#include <driver/ledc.h>
#include <esp_err.h>
#include <esp_log.h>
#include <nvs_flash.h>
#include <esp_rom_md5.h>

#include <borneo/common.h>
#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>

#include "../lyfi-events.h"
#include "led.h"

#define LED_NVS_NS "led"
#define LED_NVS_KEY_RUNNING_MODE "mode"
#define LED_NVS_KEY_MANUAL_COLOR "mcolor"
#define LED_NVS_KEY_SUN_COLOR "suncolor"
#define LED_NVS_KEY_SCHEDULER "sch"
#define LED_NVS_KEY_TEMPORARY_DURATION "tmpdur"
#define LED_NVS_KEY_CORRECTION_METHOD "corrmtd"
#define LED_NVS_KEY_PWM_FREQ "pwmfreq"
#define LED_NVS_KEY_LOC "loc"
#define LED_NVS_KEY_TZ_ENABLED "tz_en"
#define LED_NVS_KEY_TZ_OFFSET "tz_off"
#define LED_NVS_KEY_ACCLIMATION_ENABLED "acc.en"
#define LED_NVS_KEY_ACCLIMATION_START "acc.start"
#define LED_NVS_KEY_ACCLIMATION_DURATION "acc.days"
#define LED_NVS_KEY_ACCLIMATION_START_PERCENT "acc.pc"

#define TAG "led.settings"

static const struct led_user_settings LED_DEFAULT_SETTINGS = {
    .mode = LED_MODE_MANUAL,
    .temporary_duration = 20,
    .manual_color = {
// From kconfig
#if CONFIG_LYFI_LED_CH0_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH1_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH2_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH3_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH4_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH5_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH6_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH7_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH8_ENABLED
        5,
#endif
#if CONFIG_LYFI_LED_CH9_ENABLED
        5,
#endif
    },

    .correction_method = LED_CORRECTION_LOG,

    .sun_color = {0},
    .scheduler = { 0 },

    .location = { // Kunming, China
        .lat = 25.0430f,
        .lng = 102.7062f,
    },
    .tz_offset = 8 * 3600, // UTC+8

    .flags = 0ULL,

    .acclimation = {
        .start_utc = 0,
        .duration = 30,
        .start_percent = 30,
    },
}
;

extern struct led_status _led;

int led_load_factory_settings(struct led_factory_settings* factory_settings)
{
    nvs_handle_t handle;
    BO_TRY(bo_nvs_factory_open(LED_NVS_NS, NVS_READWRITE, &handle));
    BO_NVS_AUTO_CLOSE(handle);

    int rc;
    {
        rc = nvs_get_u16(handle, LED_NVS_KEY_PWM_FREQ, &factory_settings->pwm_freq);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            factory_settings->pwm_freq = CONFIG_LYFI_DEFAULT_PWM_FREQ;
            rc = 0;
        }
        if (rc) {
            return rc;
        }
    }

    return rc;
}

int led_load_user_settings()
{
    struct led_user_settings* settings = &_led.settings;
    size_t size;

    nvs_handle_t handle;
    BO_TRY(bo_nvs_user_open(LED_NVS_NS, NVS_READWRITE, &handle));
    BO_NVS_AUTO_CLOSE(handle);

    int rc;

    {
        rc = nvs_get_u8(handle, LED_NVS_KEY_RUNNING_MODE, &settings->mode);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->mode = LED_DEFAULT_SETTINGS.mode;
            rc = 0;
        }
        if (rc) {
            return rc;
        }
    }

    {
        rc = nvs_get_u32(handle, LED_NVS_KEY_TEMPORARY_DURATION, &settings->temporary_duration);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->temporary_duration = LED_DEFAULT_SETTINGS.temporary_duration;
            rc = 0;
        }
        if (rc) {
            return rc;
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
            return rc;
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
            return rc;
        }
    }

    {
        size = sizeof(led_color_t);
        rc = nvs_get_blob(handle, LED_NVS_KEY_SUN_COLOR, &settings->sun_color, &size);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            memset(settings->sun_color, 0, sizeof(led_color_t));
            rc = 0;
        }
        if (rc) {
            return rc;
        }
    }

    {
        rc = nvs_get_u8(handle, LED_NVS_KEY_CORRECTION_METHOD, &settings->correction_method);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->correction_method = LED_DEFAULT_SETTINGS.correction_method;
            rc = 0;
        }
        if (rc) {
            return rc;
        }
    }

    {
        size = sizeof(struct geo_location);
        rc = nvs_get_blob(handle, LED_NVS_KEY_LOC, &settings->location, &size);
        if (rc == 0) {
            settings->flags |= LED_OPTION_HAS_GEO_LOCATION;
        }
        else if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->flags &= ~LED_OPTION_HAS_GEO_LOCATION;
            rc = 0;
        }
        if (rc) {
            return rc;
        }
    }

    {
        uint8_t tz_en = 0;
        rc = nvs_get_u8(handle, LED_NVS_KEY_TZ_ENABLED, &tz_en);
        if (rc == 0) {
            if (tz_en) {
                settings->flags |= LED_OPTION_TZ_ENABLED;
            }
            else {
                settings->flags &= ~LED_OPTION_TZ_ENABLED;
            }
        }
        else if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->flags &= ~LED_OPTION_TZ_ENABLED;
        }
        else if (rc) {
            return rc;
        }
    }

    {
        rc = nvs_get_i32(handle, LED_NVS_KEY_TZ_OFFSET, &settings->tz_offset);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->tz_offset = LED_DEFAULT_SETTINGS.tz_offset;
        }
        else if (rc) {
            return rc;
        }
    }

    {
        uint8_t acc_en = 0;
        rc = nvs_get_u8(handle, LED_NVS_KEY_ACCLIMATION_ENABLED, &acc_en);
        if (rc == 0) {
            if (acc_en) {
                settings->flags |= LED_OPTION_ACCLIMATION_ENABLED;
            }
            else {
                settings->flags &= ~LED_OPTION_ACCLIMATION_ENABLED;
            }
        }
        else if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->flags &= ~LED_OPTION_ACCLIMATION_ENABLED;
        }
        else if (rc) {
            return rc;
        }
    }

    {
        rc = nvs_get_i64(handle, LED_NVS_KEY_ACCLIMATION_START, &settings->acclimation.start_utc);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->acclimation.start_utc = LED_DEFAULT_SETTINGS.acclimation.start_utc;
        }
        else if (rc) {
            return rc;
        }
    }

    {
        rc = nvs_get_u8(handle, LED_NVS_KEY_ACCLIMATION_DURATION, &settings->acclimation.duration);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->acclimation.duration = LED_DEFAULT_SETTINGS.acclimation.duration;
            rc = 0;
        }
        else if (rc) {
            return rc;
        }
    }

    {
        rc = nvs_get_u8(handle, LED_NVS_KEY_ACCLIMATION_START_PERCENT, &settings->acclimation.start_percent);
        if (rc == ESP_ERR_NVS_NOT_FOUND) {
            settings->acclimation.start_percent = LED_DEFAULT_SETTINGS.acclimation.start_percent;
            rc = 0;
        }
        else if (rc) {
            return rc;
        }
    }

    // TODO
    // Loading the brightness and power settings...
#ifdef CONFIG_LYFI_STANDALONE_CONTROLLER
#endif // CONFIG_LYFI_STANDALONE_CONTROLLER

    return rc;
}

int led_save_user_settings()
{
    xSemaphoreTake(_led.settings_lock, portMAX_DELAY);
    BO_SEM_AUTO_RELEASE(_led.settings_lock);

    ESP_LOGI(TAG, "Saving dimming settings...");

    const struct led_user_settings* settings = &_led.settings;
    nvs_handle_t handle;
    BO_TRY(bo_nvs_user_open(LED_NVS_NS, NVS_READWRITE, &handle));
    BO_NVS_AUTO_CLOSE(handle);

    BO_TRY(nvs_set_u8(handle, LED_NVS_KEY_RUNNING_MODE, settings->mode));
    BO_TRY(nvs_set_u32(handle, LED_NVS_KEY_TEMPORARY_DURATION, settings->temporary_duration));
    BO_TRY(nvs_set_u8(handle, LED_NVS_KEY_CORRECTION_METHOD, settings->correction_method));
    BO_TRY(nvs_set_blob(handle, LED_NVS_KEY_SCHEDULER, &settings->scheduler, sizeof(struct led_scheduler)));
    BO_TRY(nvs_set_blob(handle, LED_NVS_KEY_MANUAL_COLOR, settings->manual_color, sizeof(led_color_t)));
    BO_TRY(nvs_set_blob(handle, LED_NVS_KEY_SUN_COLOR, settings->sun_color, sizeof(led_color_t)));

    if (led_has_geo_location()) {
        BO_TRY(nvs_set_blob(handle, LED_NVS_KEY_LOC, &settings->location, sizeof(struct geo_location)));
    }

    BO_TRY(nvs_set_u8(handle, LED_NVS_KEY_TZ_ENABLED, (uint8_t)(settings->flags & LED_OPTION_TZ_ENABLED)));
    BO_TRY(nvs_set_i32(handle, LED_NVS_KEY_TZ_OFFSET, settings->tz_offset));
    BO_TRY(nvs_set_u8(handle, LED_NVS_KEY_ACCLIMATION_ENABLED, (uint8_t)led_acclimation_is_enabled()));
    BO_TRY(nvs_set_i64(handle, LED_NVS_KEY_ACCLIMATION_START, settings->acclimation.start_utc));
    BO_TRY(nvs_set_u8(handle, LED_NVS_KEY_ACCLIMATION_DURATION, settings->acclimation.duration));
    BO_TRY(nvs_set_u8(handle, LED_NVS_KEY_ACCLIMATION_START_PERCENT, settings->acclimation.start_percent));

    BO_TRY(nvs_commit(handle));
    ESP_LOGI(TAG, "Dimming settings updated.");

    return 0;
}

bool led_has_geo_location()
{
    // TODO lock
    return _led.settings.flags & LED_OPTION_HAS_GEO_LOCATION;
}

int led_set_geo_location(const struct geo_location* location)
{
    // TODO lock
    if (location == NULL) {
        return -EINVAL;
    }

    if (isnan(location->lat) || isnan(location->lng) || isinf(location->lat) || isinf(location->lng)) {
        return -EINVAL;
    }

    // lat [-90.0, 90.0]
    if (location->lat < -90.0f || location->lat > 90.0f) {
        return -EINVAL;
    }
    // lng [-180.0, 180.0]
    if (location->lng < -180.0f || location->lng > 180.0f) {
        return -EINVAL;
    }
    _led.settings.location.lat = location->lat;
    _led.settings.location.lng = location->lng;
    _led.settings.flags |= LED_OPTION_HAS_GEO_LOCATION;

    BO_TRY(led_save_user_settings());

    BO_TRY(esp_event_post(BO_SYSTEM_EVENTS, BO_EVENT_GEO_LOCATION_CHANGED, NULL, 0, portMAX_DELAY));

    return 0;
}

int led_tz_enable(bool enabled)
{
    // TODO lock
    if (enabled) {
        if (_led.settings.tz_offset < -43200 || _led.settings.tz_offset > 50400) {
            return -EINVAL;
        }
        _led.settings.flags |= LED_OPTION_TZ_ENABLED;
    }
    else {
        _led.settings.flags &= ~LED_OPTION_TZ_ENABLED;
    }
    BO_TRY(led_save_user_settings());
    return 0;
}

int led_tz_set_offset(int32_t offset)
{
    // TODO lock

    // -12*3600 ~ +14*3600（-43200 ~ +50400），UTC-12:00 ~ UTC+14:00
    if (offset < -43200 || offset > 50400) {
        return -EINVAL;
    }

    _led.settings.tz_offset = offset;
    BO_TRY(led_save_user_settings());
    return 0;
}
