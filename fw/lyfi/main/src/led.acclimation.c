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

#include "lyfi-events.h"
#include "algo.h"
#include "led.h"

#define TAG "led.acclimation"

#define SECS_PER_DAY 86400

extern struct led_status _led;

bool led_acclimation_inprogress() { return _led.settings.acclimation.start_utc > 0; }

int led_acclimation_drive(time_t utc_now, led_color_t color)
{
    struct led_acclimation_settings* acc = &_led.settings.acclimation;
    time_t end_time_utc = acc->start_utc + (SECS_PER_DAY * acc->duration);
    if (utc_now <= end_time_utc) {
        int days_elapsed = (int)((end_time_utc - utc_now) / SECS_PER_DAY);
        int total_increment = 100 - acc->start_percent;
        int current_increment = days_elapsed * total_increment;
        int percent = acc->start_percent + (current_increment + acc->duration / 2) / acc->duration;
        for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
            if (end_time_utc <= utc_now) {
                return (led_brightness_t)(((uint32_t)color[ch] * percent + 50) / 100);
            }
        }
        return 0;
    }
    else {
        BO_TRY(led_acclimation_terminate());
    }
    return 0;
}

int led_acclimation_set(const struct led_acclimation_settings* settings)
{
    if (settings == NULL) {
        return -EINVAL;
    }
    memcpy(&_led.settings.acclimation, settings, sizeof(struct led_acclimation_settings));
    BO_TRY(led_save_user_settings());
    return 0;
}

int led_acclimation_terminate()
{
    _led.settings.acclimation.start_utc = 0;
    return 0;
}