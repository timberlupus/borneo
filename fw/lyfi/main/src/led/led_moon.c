#include <string.h>
#include <errno.h>
#include <math.h>

#include <esp_log.h>

#include <borneo/system.h>
#include <borneo/utils/time.h>

#include "../moon.h"
#include "../solar.h"
#include "led.h"

#define TAG "led.moon"

#define MOON_RECALC_DELAY_SEC 5
#define MOON_RECALC_RETRY_SEC 3600
#define SECS_PER_DAY 86400

static bool led_moon_can_active() { return led_has_geo_location() && bo_tz_get() != NULL; }

bool led_moon_is_enabled() { return (_led.settings.flags & LED_OPTION_MOON_ENABLED) != 0; }

int led_moon_init()
{
    if (!led_moon_is_enabled()) {
        return 0;
    }

    return led_moon_update_scheduler();
}

static void led_moon_reset_scheduler(time_t utc_now)
{
    struct led_scheduler* sch = &_led.moon_scheduler;
    memset(sch, 0, sizeof(*sch));
    _led.moon_next_recalc_time_utc = utc_now + MOON_RECALC_RETRY_SEC;
    _led.moon_activated = false;
}

int led_moon_update_scheduler()
{
    if (!led_moon_is_enabled()) {
        return -EINVAL;
    }

    if (!led_moon_can_active()) {
        return -EINVAL;
    }

    time_t utc_now = time(NULL);
    struct tm local_tm;

    localtime_r(&utc_now, &local_tm);

    float local_tz_offset = solar_calculate_local_tz_offset(&local_tm);

    float target_tz_offset
        = _led.settings.flags & LED_OPTION_TZ_ENABLED ? _led.settings.tz_offset / 3600.0f : local_tz_offset;

    float moonrise = 0.0f;
    float moonset = 0.0f;
    float decl = 0.0f;
    float illum = 0.0f;

    int rc = moon_calculate_rise_set(_led.settings.location.lat, _led.settings.location.lng, utc_now, target_tz_offset,
                                     local_tz_offset, &local_tm, &moonrise, &moonset, &decl, &illum);
    if (rc != 0) {
        led_moon_reset_scheduler(utc_now);
        return rc;
    }

    struct moon_instant instants[MOON_INSTANTS_COUNT];
    rc = moon_generate_instants(moonrise, moonset, illum, instants);
    if (rc != 0) {
        led_moon_reset_scheduler(utc_now);
        return rc;
    }

    struct led_scheduler* sch = &_led.moon_scheduler;
    memset(sch, 0, sizeof(*sch));
    sch->item_count = MOON_INSTANTS_COUNT;

    for (size_t i = 0; i < MOON_INSTANTS_COUNT; i++) {
        float time_hours = instants[i].time;
        if (time_hours < 0.0f) {
            time_hours = 0.0f;
        }
        uint32_t instant = (uint32_t)roundf(time_hours * 3600.0f);
        if (instant > (SECS_PER_DAY * 2 - 1)) {
            instant = SECS_PER_DAY * 2 - 1;
        }
        sch->items[i].instant = instant;
        for (size_t ch = 0; ch < led_channel_count(); ch++) {
            uint16_t brightness = (uint16_t)roundf((float)_led.settings.moon_color[ch] * instants[i].brightness);
            if (brightness > LED_BRIGHTNESS_MAX) {
                brightness = LED_BRIGHTNESS_MAX;
            }
            sch->items[i].color[ch] = brightness;
        }
    }

    struct tm local_midnight = local_tm;
    local_midnight.tm_hour = 0;
    local_midnight.tm_min = 0;
    local_midnight.tm_sec = 0;
    local_midnight.tm_isdst = -1;

    time_t local_midnight_utc = mktime(&local_midnight);
    uint32_t last_instant = sch->items[sch->item_count - 1].instant;
    time_t next_recalc = local_midnight_utc + (time_t)last_instant + MOON_RECALC_DELAY_SEC;
    if (next_recalc <= utc_now) {
        next_recalc += SECS_PER_DAY;
    }

    _led.moon_next_recalc_time_utc = next_recalc;
    _led.moon_activated = true;

    return 0;
}

int led_moon_set(const led_color_t color, bool enabled)
{
    if (color == NULL) {
        return -EINVAL;
    }

    for (size_t ch = 0; ch < led_channel_count(); ch++) {
        if (color[ch] > LED_BRIGHTNESS_MAX) {
            return -EINVAL;
        }
    }

    portENTER_CRITICAL(&g_led_spinlock);
    memcpy(_led.settings.moon_color, color, sizeof(led_color_t));
    if (enabled) {
        _led.settings.flags |= LED_OPTION_MOON_ENABLED;
    }
    else {
        _led.settings.flags &= ~LED_OPTION_MOON_ENABLED;
        _led.moon_activated = false;
        _led.moon_next_recalc_time_utc = 0;
        memset(&_led.moon_scheduler, 0, sizeof(_led.moon_scheduler));
    }
    portEXIT_CRITICAL(&g_led_spinlock);

    BO_TRY(led_save_user_settings());

    if (enabled) {
        int rc = led_moon_update_scheduler();
        if (rc != 0) {
            ESP_LOGW(TAG, "Failed to update moon scheduler: %d", rc);
        }
    }

    return 0;
}

int led_moon_apply_filter(time_t utc_now, led_color_t color)
{
    if (!led_moon_is_enabled()) {
        return 0;
    }

    if (_led.settings.mode == LED_MODE_MANUAL) {
        return 0;
    }

    if (!led_moon_can_active()) {
        return 0;
    }

    if (_led.moon_next_recalc_time_utc > 0 && utc_now >= _led.moon_next_recalc_time_utc) {
        int rc = led_moon_update_scheduler();
        if (rc != 0) {
            ESP_LOGW(TAG, "Moon scheduler refresh failed: %d", rc);
        }
    }

    if (_led.moon_scheduler.item_count == 0) {
        return 0;
    }

    struct tm local_tm = { 0 };
    localtime_r(&utc_now, &local_tm);

    led_color_t moon_color;
    led_sch_compute_color(&_led.moon_scheduler, &local_tm, moon_color);

    for (size_t ch = 0; ch < led_channel_count(); ch++) {
        if (_led.settings.moon_color[ch] == 0) {
            continue;
        }
        if (moon_color[ch] > color[ch]) {
            color[ch] = moon_color[ch];
        }
    }

    return 0;
}
