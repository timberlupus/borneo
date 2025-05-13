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

#define TAG "led.fade"

#define FADE_PERIOD_MS 10000
#define FADE_ON_PERIOD_MS 5000
#define FADE_OFF_PERIOD_MS 3000

extern struct led_status _led;

int led_fade_to_color(const led_color_t color, uint32_t duration_ms)
{
    if (_led.state == LED_STATE_DIMMING) {
        return -EINVAL;
    }

    if (duration_ms < 10) {
        return -EINVAL;
    }

    int64_t now = (esp_timer_get_time() + 500LL) / 1000LL;
    _led.fade_start_time_ms = now;
    _led.fade_duration_ms = duration_ms;
    BO_TRY(led_get_color(_led.fade_start_color));
    memcpy(_led.fade_end_color, color, sizeof(led_color_t));
    return 0;
}

int led_fade_to_normal()
{
    led_color_t end_color;

    time_t now = time(NULL) * 1000;
    now += FADE_ON_PERIOD_MS;
    now /= 1000;
    struct tm local_tm = { 0 };
    localtime_r(&now, &local_tm);

    switch (_led.settings.mode) {

    case LED_MODE_MANUAL: {
        memcpy(end_color, _led.settings.manual_color, sizeof(led_color_t));
    } break;

    case LED_MODE_SCHEDULED: {
        led_sch_compute_color(&_led.settings.scheduler, &local_tm, end_color);
    } break;

    case LED_MODE_SUN: {
        led_sch_compute_color(&_led.sun_scheduler, &local_tm, end_color);
    } break;

    default:
        assert(false);
        break;
    }

    BO_TRY(led_fade_to_color(end_color, FADE_ON_PERIOD_MS));

    return 0;
}

int led_fade_stop()
{
    _led.fade_start_time_ms = 0LL;
    return 0;
}

void led_fade_drive()
{
    if (!led_is_fading()) {
        return;
    }

    int64_t now = (esp_timer_get_time() + 500LL) / 1000LL;
    if (now >= _led.fade_start_time_ms + _led.fade_duration_ms) {
        BO_MUST(led_fade_stop());
        BO_MUST(led_update_color(_led.fade_end_color));
        return;
    }

    uint32_t elapsed_time_ms = (uint32_t)(now - _led.fade_start_time_ms);
    uint32_t progress = (elapsed_time_ms * 65536ULL + (_led.fade_duration_ms / 2)) / _led.fade_duration_ms;

    led_color_t color;
    for (size_t ich = 0; ich < LYFI_LED_CHANNEL_COUNT; ich++) {
        int32_t delta = (int32_t)(_led.fade_end_color[ich] - _led.fade_start_color[ich]) * progress;
        color[ich] = _led.fade_start_color[ich] + ((delta + (1 << 15)) >> 16);
    }
    BO_MUST(led_update_color(color));
}

inline bool led_is_fading() { return _led.fade_start_time_ms > 0LL; }
