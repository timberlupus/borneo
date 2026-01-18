#include <string.h>
#include <math.h>

#include <esp_system.h>
#include <esp_log.h>
#include <esp_random.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <drvfx/drvfx.h>

#include <borneo/timer.h>

#include "led.h"

#define TAG "lyfi-cloud"

// Cloud overlay (micro cloud shadow) configuration
#define CLOUD_DROP_MIN_BP 3000 // 30%
#define CLOUD_DROP_MAX_BP 6000 // 60%
#define CLOUD_DURATION_MIN_MS 30000 // 30 seconds
#define CLOUD_DURATION_MAX_MS 300000 // 5 minutes
#define CLOUD_INTERVAL_MIN_MS 300000 // 5 minutes
#define CLOUD_INTERVAL_MAX_MS 1800000 // 30 minutes

/**
 * @brief Generate random value in range [min, max] inclusive.
 */
static inline uint32_t _rand_range(uint32_t min, uint32_t max)
{
    if (max <= min) {
        return min;
    }
    return min + (esp_random() % (max - min + 1));
}

int led_cloud_init()
{
    // Cloud state will be zeroed by memset in led_init()
    // This function serves as a hook for potential future initialization
    return 0;
}

int led_cloud_enable(bool enabled)
{
    portENTER_CRITICAL(led_get_lock());

    if (enabled) {
        _led.settings.flags |= LED_OPTION_CLOUD_ENABLED;
    }
    else {
        _led.settings.flags &= ~LED_OPTION_CLOUD_ENABLED;
        _led.cloud_activated = false;
    }

    portEXIT_CRITICAL(led_get_lock());
    return 0;
}

bool led_cloud_is_enabled() { return (_led.settings.flags & LED_OPTION_CLOUD_ENABLED) != 0; }

bool led_cloud_is_activated() { return _led.cloud_activated; }

void led_cloud_drive(led_color_t color)
{
    if (!(_led.settings.flags & LED_OPTION_CLOUD_ENABLED)) {
        return;
    }

    uint32_t now_ms = (uint32_t)bo_timer_uptime_ms();

    bool active;
    uint32_t start_ms;
    uint32_t duration_ms;
    uint16_t drop_bp;
    bool just_activated = false;
    uint32_t log_duration_ms = 0;
    uint16_t log_drop_bp = 0;
    uint32_t log_next_in_ms = 0;

    // Update/arm cloud state once per frame under lock
    portENTER_CRITICAL(led_get_lock());
    if (!_led.cloud_activated && now_ms >= _led.cloud_next_fire_ms) {
        _led.cloud_drop_bp = (uint16_t)_rand_range(CLOUD_DROP_MIN_BP, CLOUD_DROP_MAX_BP);
        _led.cloud_duration_ms = _rand_range(CLOUD_DURATION_MIN_MS, CLOUD_DURATION_MAX_MS);
        _led.cloud_start_ms = now_ms;
        _led.cloud_activated = true;
        _led.cloud_next_fire_ms = now_ms + _rand_range(CLOUD_INTERVAL_MIN_MS, CLOUD_INTERVAL_MAX_MS);

        // Prepare log details to print outside the critical section
        just_activated = true;
        log_duration_ms = _led.cloud_duration_ms;
        log_drop_bp = _led.cloud_drop_bp;
        log_next_in_ms = (_led.cloud_next_fire_ms > now_ms) ? (_led.cloud_next_fire_ms - now_ms) : 0;
    }

    active = _led.cloud_activated;
    start_ms = _led.cloud_start_ms;
    duration_ms = _led.cloud_duration_ms;
    drop_bp = _led.cloud_drop_bp;

    // If expired, clear active flag immediately
    if (active && duration_ms > 0 && now_ms - start_ms >= duration_ms) {
        _led.cloud_activated = false;
        active = false;
    }
    portEXIT_CRITICAL(led_get_lock());

    if (just_activated) {
        ESP_LOGI(TAG, "Cloud activated: duration=%u ms, drop=%u bp, next_fire_in=%u ms", (unsigned)log_duration_ms,
                 (unsigned)log_drop_bp, (unsigned)log_next_in_ms);
    }

    if (!active || duration_ms == 0) {
        return;
    }

    uint32_t elapsed = now_ms - start_ms;
    if (elapsed > duration_ms) {
        elapsed = duration_ms;
    }

    // Triangular envelope: 0 -> 1 -> 0 in Q15
    uint32_t progress_q15 = (uint32_t)(((uint64_t)elapsed << 15) / duration_ms);
    if (progress_q15 > 32768U) {
        progress_q15 = 32768U;
    }
    uint32_t envelope_q15 = (progress_q15 <= 16384U) ? (progress_q15 << 1) : ((32768U - progress_q15) << 1);

    // factor_bp in basis points: 10000 = 1.0
    uint32_t factor_bp = 10000U - (uint32_t)(((uint64_t)drop_bp * envelope_q15 + (1 << 14)) >> 15);

    for (size_t ch = 0; ch < led_channel_count(); ch++) {
        uint32_t scaled = ((uint64_t)color[ch] * factor_bp + 5000U) / 10000U;
        if (scaled > LED_BRIGHTNESS_MAX) {
            scaled = LED_BRIGHTNESS_MAX;
        }
        color[ch] = (led_brightness_t)scaled;
    }
}
