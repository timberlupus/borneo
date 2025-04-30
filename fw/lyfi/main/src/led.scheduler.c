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

#define SECS_PER_DAY 172800

#define TAG "led.scheduler"

struct sch_time_pair {
    const struct led_scheduler_item* begin;
    const struct led_scheduler_item* end;
};

static int sch_find_closest_time_range(const struct led_scheduler* sch, uint32_t instant, struct sch_time_pair* result);

extern struct led_status _led;

void led_sch_compute_color_in_range(led_color_t color, const struct tm* tm_local,
                                    const struct led_scheduler_item* range_begin,
                                    const struct led_scheduler_item* range_end)
{
    int32_t now_instant = (tm_local->tm_hour * 3600) + (tm_local->tm_min * 60) + tm_local->tm_sec;
    if (range_begin->instant >= SECS_PER_DAY) {
        now_instant += SECS_PER_DAY;
    }

    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        led_brightness_t begin_brightness = range_begin->color[ch];
        led_brightness_t end_brightness = range_end->color[ch];
        int32_t value = linear_interpolate_i32(range_begin->instant, begin_brightness, range_end->instant,
                                               end_brightness, now_instant);
        if (value < 0) {
            value = 0;
        }
        else if (value > LED_BRIGHTNESS_MAX) {
            value = LED_BRIGHTNESS_MAX;
        }
        color[ch] = value;
    }
}

void led_sch_compute_color(const struct led_scheduler* sch, const struct tm* local_tm, led_color_t color)
{
    if (sch->item_count == 0) {
        memset(color, 0, sizeof(led_color_t));
        return;
    }

    // time_t utc_now = _led.state == LED_STATE_PREVIEW ? _led.preview_state_clock : time(NULL);

    uint32_t local_instant = (local_tm->tm_hour * 3600) + (local_tm->tm_min * 60) + local_tm->tm_sec;
    uint32_t local_next_day_instant = SECS_PER_DAY + local_instant;

    // Find the instant range
    struct sch_time_pair pair;

    int rc = sch_find_closest_time_range(sch, local_instant, &pair);
    if (rc == -ENOENT) { // Try the time of next day
        rc = sch_find_closest_time_range(sch, local_next_day_instant, &pair);
    }
    if (rc && rc != -ENOENT) {
        // we got an error
        ESP_LOGE(TAG, "Failed to find scheduler item with instant(%lu), errno=%d", local_instant, rc);
        memset(color, 0, sizeof(led_color_t));
        return;
    }

    // Open range
    if (pair.begin != NULL && pair.end == NULL) {
        memcpy(color, pair.begin->color, sizeof(led_color_t));
        return;
    }

    // Between two instants
    if (pair.begin != NULL && pair.end != NULL) {
        led_sch_compute_color_in_range(color, local_tm, pair.begin, pair.end);
    }
}

int sch_find_closest_time_range(const struct led_scheduler* sch, uint32_t instant, struct sch_time_pair* result)
{
    if (result == NULL) {
        return -EINVAL;
    }

    if (sch->item_count == 0) {
        return -ENOENT;
    }

    const struct led_scheduler_item* items = sch->items;
    size_t size = sch->item_count;

    result->begin = NULL;
    result->end = NULL;

    if (instant < items[0].instant) {
        return -ENOENT;
    }

    for (size_t i = 0; i < size; i++) {
        if (instant < items[i].instant) {
            if (i == 0) {
                return -ENOENT;
            }
            else {
                result->begin = &items[i - 1];
                result->end = &items[i];
                return 0;
            }
        }
    }
    // now_instant >= all items
    result->begin = &items[size - 1];
    return 0;
}

void led_sch_drive()
{
    assert((_led.state == LED_STATE_PREVIEW || _led.state == LED_STATE_NORMAL)
           && _led.settings.mode == LED_MODE_SCHEDULED);

    led_color_t color;
    time_t utc_now = _led.state == LED_STATE_PREVIEW ? _led.preview_state_clock : time(NULL);
    struct tm local_tm;
    localtime_r(&utc_now, &local_tm);

    led_sch_compute_color(&_led.settings.scheduler, &local_tm, color);

    BO_MUST(led_update_color(color));
}