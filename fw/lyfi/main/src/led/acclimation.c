#include <string.h>
#include <errno.h>
#include <math.h>
#include <assert.h>

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
#include <borneo/utils/time.h>

#include "../lyfi-events.h"
#include "../algo.h"
#include "led.h"

#define TAG "led.acclimation"

#define SECS_PER_DAY 86400

bool led_acclimation_is_enabled() { return _led.settings.flags & LED_OPTION_ACCLIMATION_ENABLED; }

bool led_acclimation_is_activated() { return led_acclimation_is_enabled() && _led.acclimation_activated; }

int led_acclimation_drive(time_t utc_now, led_color_t color)
{
    if (led_acclimation_is_activated() && !led_acclimation_is_enabled()) {
        _led.acclimation_activated = false;
        return 0;
    }

    if (!led_acclimation_is_enabled()) {
        return 0;
    }

    struct led_acclimation_settings* acc = &_led.settings.acclimation;
    time_t end_time_utc = acc->start_utc + (SECS_PER_DAY * acc->duration);

    if (utc_now >= acc->start_utc && utc_now <= end_time_utc) {
        if (!_led.acclimation_activated) {
            _led.acclimation_activated = true;
        }

        int days_elapsed = (int)((utc_now - acc->start_utc) / SECS_PER_DAY);

        if (days_elapsed > acc->duration) {
            days_elapsed = acc->duration;
        }

        int total_increment = 100 - acc->start_percent;
        int percent = acc->start_percent + (days_elapsed * total_increment) / acc->duration;

        if (percent > 100) {
            percent = 100;
        }

        for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
            color[ch] = (led_brightness_t)(((uint32_t)color[ch] * percent + 50) / 100);
        }
        return 0;
    }
    else {
        if (led_acclimation_is_enabled()) {
            BO_TRY(led_acclimation_terminate());
        }
    }
    return 0;
}

int led_acclimation_set(const struct led_acclimation_settings* settings, bool enabled)
{
    if (settings == NULL) {
        return -EINVAL;
    }
    memcpy(&_led.settings.acclimation, settings, sizeof(struct led_acclimation_settings));
    if (enabled) {
        _led.settings.flags |= LED_OPTION_ACCLIMATION_ENABLED;
    }
    else {
        _led.settings.flags &= ~LED_OPTION_ACCLIMATION_ENABLED;
    }
    BO_TRY(led_save_user_settings());
    ESP_LOGI(TAG, "Acclimation settings has been updated.");
    return 0;
}

int led_acclimation_terminate()
{
    if (!led_acclimation_is_enabled()) {
        return -EINVAL;
    }

    _led.acclimation_activated = false;
    _led.settings.flags &= ~LED_OPTION_ACCLIMATION_ENABLED;
    BO_TRY(led_save_user_settings());
    ESP_LOGI(TAG, "Acclimation settings has been terminated.");
    return 0;
}