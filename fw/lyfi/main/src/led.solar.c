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

#include "solar.h"
#include "lyfi-events.h"
#include "algo.h"
#include "led.h"

#define TAG "led.solar"

extern struct led_status _led;

int led_sun_init()
{
    if(_led.settings.mode != LED_MODE_SUN) {
        return -EINVAL;
    }
    BO_TRY(led_sun_update_scheduler());
    return 0;
}

int led_sun_update_scheduler()
{
    time_t now;
    struct tm local_tm;

    time(&now);
    localtime_r(&now, &local_tm);

    double tz_offset = solar_calculate_timezone_offset(&local_tm);
    double sunrise, sunset;
    //TODO FIXME
    BO_TRY(solar_calculate_sunrise_sunset(25.0430, 102.7062, tz_offset, &local_tm, &sunrise, &sunset));

    struct solar_instant instants[SOLAR_INSTANTS_COUNT];
    BO_TRY(solar_generate_instants(sunrise, sunset, instants));

    struct led_scheduler* sch = &_led.sun_scheduler;
    memset(sch, 0, sizeof(struct led_scheduler));
    sch->item_count = SOLAR_INSTANTS_COUNT;
    for (size_t i = 0; i < SOLAR_INSTANTS_COUNT; i++) {
        sch->items[i].instant = (uint32_t)round(instants[i].time * 3600.0);
        // ESP_LOGI(TAG, ">>>>>>>> item %u \t instant %lu", i, sch->items[i].instant);
        for (size_t j = 0; j < LYFI_LED_CHANNEL_COUNT; j++) {
            uint16_t brightness = (uint16_t)round((double)_led.settings.sun_color[j] * instants[i].brightness);
            if (brightness > LED_BRIGHTNESS_MAX) {
                brightness = LED_BRIGHTNESS_MAX;
            }
            sch->items[i].color[j] = brightness;
            // ESP_LOGI(TAG, ">>>>>>>>>>>> brightness[%u] = %u", j, brightness);
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
    if (_led.settings.mode != LED_MODE_SUN) {
        return false;
    }
    if(_led.sun_scheduler.item_count == 0) {
        return false;
    }
    uint32_t local_instant = (local_tm->tm_hour * 3600) + (local_tm->tm_min * 60) + local_tm->tm_sec;
    return _led.sun_scheduler.items[0].instant >= local_instant
        && _led.sun_scheduler.items[_led.sun_scheduler.item_count - 1].instant <= local_instant;
}

void led_sun_drive()
{
    assert(_led.settings.mode == LED_MODE_SUN && _led.state == LED_STATE_NORMAL);
    assert(_led.sun_scheduler.item_count == SOLAR_INSTANTS_COUNT);

    led_color_t color;
    time_t utc_now = time(NULL);
    struct tm local_tm;
    localtime_r(&utc_now, &local_tm);

    led_sch_compute_color(&_led.sun_scheduler, &local_tm, color);

    ESP_ERROR_CHECK(led_update_color(color));

    if (utc_now >= _led.sun_next_reschedule_time_utc && !led_sun_is_in_progress(&local_tm)) {
        ESP_ERROR_CHECK(led_sun_update_scheduler() == 0);
    }
}