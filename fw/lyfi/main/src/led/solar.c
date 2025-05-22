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

#include "../solar.h"
#include "../lyfi-events.h"
#include "../algo.h"
#include "led.h"

#define TAG "led.solar"

extern struct led_status _led;

int led_sun_init()
{
    if (_led.settings.mode != LED_MODE_SUN) {
        return -EINVAL;
    }

    BO_TRY(led_sun_update_scheduler());
    return 0;
}

int led_sun_update_scheduler()
{
    if (!led_sun_can_active()) {
        return -EINVAL;
    }

    time_t utc_now = time(NULL);
    struct tm local_tm;

    localtime_r(&utc_now, &local_tm);

    float local_tz_offset = solar_calculate_local_tz_offset(&local_tm);

    float target_tz_offset
        = _led.settings.flags & LED_OPTION_TZ_ENABLED ? _led.settings.tz_offset / 3600.0f : local_tz_offset;

    float sunrise, noon, sunset, decl;

    BO_TRY(solar_calculate_sunrise_sunset(_led.settings.location.lat, _led.settings.location.lng, utc_now,
                                          target_tz_offset, local_tz_offset, &local_tm, &sunrise, &noon, &sunset,
                                          &decl));

    struct solar_instant instants[SOLAR_INSTANTS_COUNT];
    BO_TRY(solar_generate_instants(_led.settings.location.lat, decl, sunrise, noon, sunset, instants));

    struct led_scheduler* sch = &_led.sun_scheduler;
    memset(sch, 0, sizeof(struct led_scheduler));
    sch->item_count = SOLAR_INSTANTS_COUNT;
    for (size_t i = 0; i < SOLAR_INSTANTS_COUNT; i++) {
        sch->items[i].instant = (uint32_t)round(instants[i].time * 3600.0);
        for (size_t j = 0; j < LYFI_LED_CHANNEL_COUNT; j++) {
            uint16_t brightness = (uint16_t)roundf((float)_led.settings.sun_color[j] * instants[i].brightness);
            if (brightness > LED_BRIGHTNESS_MAX) {
                brightness = LED_BRIGHTNESS_MAX;
            }
            sch->items[i].color[j] = brightness;
        }
    };

    local_tm.tm_hour = 0;
    local_tm.tm_min = 0;
    local_tm.tm_sec = 0;
    local_tm.tm_mday += 1;
    local_tm.tm_isdst = -1;
    _led.sun_next_reschedule_time_utc = mktime(&local_tm);

    return 0;
}

bool led_sun_is_in_progress(const struct tm* local_tm)
{
    if (!led_has_geo_location()) {
        return false;
    }
    if (_led.settings.mode != LED_MODE_SUN) {
        return false;
    }
    if (_led.sun_scheduler.item_count == 0) {
        return false;
    }
    uint32_t local_instant = (local_tm->tm_hour * 3600) + (local_tm->tm_min * 60) + local_tm->tm_sec;
    return _led.sun_scheduler.items[0].instant >= local_instant
        && _led.sun_scheduler.items[_led.sun_scheduler.item_count - 1].instant <= local_instant;
}

void led_sun_drive(time_t utc_now, led_color_t color)
{
    assert(led_sun_can_active());
    assert(_led.settings.mode == LED_MODE_SUN && led_get_state() == LED_STATE_NORMAL);
    assert(_led.sun_scheduler.item_count == SOLAR_INSTANTS_COUNT);

    struct tm local_tm = { 0 };
    localtime_r(&utc_now, &local_tm);

    led_sch_compute_color(&_led.sun_scheduler, &local_tm, color);

    if (utc_now >= _led.sun_next_reschedule_time_utc && !led_sun_is_in_progress(&local_tm)) {
        BO_MUST(led_sun_update_scheduler());
    }
}

bool led_sun_can_active()
{
    //
    return led_has_geo_location() && bo_tz_get() != NULL;
}