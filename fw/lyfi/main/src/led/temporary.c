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

#define TAG "led.temporary"

#define TEMPORARY_FADE_PERIOD_MS 5000

extern struct led_status _led;

int led_set_temporary_duration(uint16_t duration)
{
    _led.settings.temporary_duration = duration;
    BO_TRY(led_save_user_settings());
    return 0;
}

int32_t led_get_temporary_remaining()
{
    if (_led.state == LED_STATE_TEMPORARY) {
        int64_t now = (esp_timer_get_time() + 500LL) / 1000LL;
        return (int32_t)((_led.temporary_off_time - now + 500LL) / 1000LL);
    }
    else {
        return -1;
    }
}

int led_temporary_state_entry(uint8_t prev_state)
{
    if (!bo_power_is_on()) {
        return -EINVAL;
    }

    if (prev_state != LED_STATE_NORMAL) {
        return -EINVAL;
    }

    if (_led.settings.mode != LED_MODE_SUN && _led.settings.mode != LED_MODE_SCHEDULED) {
        return -EINVAL;
    }

    int64_t now = (esp_timer_get_time() + 500LL) / 1000LL;

    _led.temporary_off_time = now + (_led.settings.temporary_duration * 60 * 1000) + TEMPORARY_FADE_PERIOD_MS;
    _led.state = LED_STATE_TEMPORARY;

    BO_TRY(led_fade_to_color(_led.settings.manual_color, TEMPORARY_FADE_PERIOD_MS));
    return 0;
}

int led_temporary_state_exit()
{
    if (_led.state != LED_STATE_TEMPORARY) {
        return -1;
    }

    _led.temporary_off_time = 0;
    BO_TRY(led_switch_state(LED_STATE_NORMAL));
    return 0;
}

void led_temporary_state_drive()
{
    if (_led.state != LED_STATE_TEMPORARY) {
        return;
    }

    int64_t now = (esp_timer_get_time() + 500LL) / 1000LL;

    if (now >= _led.temporary_off_time) {
        BO_MUST(led_temporary_state_exit());
    }
    else {
        if (!led_is_fading()) {
            led_update_color(_led.settings.manual_color);
        }
        else {
            led_fade_drive();
        }
    }
}
