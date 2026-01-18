#include <math.h>
#include <string.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <esp_system.h>
#include <esp_timer.h>
#include <esp_log.h>

#include <borneo/timer.h>

#include "led.h"

#define TAG "led.disco"

// Maximum brightness for disco mode (50% of LED_BRIGHTNESS_MAX - safe for aquarium)
#define DISCO_MAX_BRIGHTNESS 2047

// Transition duration between effects (in milliseconds)
#define DISCO_TRANSITION_DURATION_MS 400

// Effect duration range (in milliseconds) - faster paced
#define DISCO_EFFECT_MIN_DURATION_MS 1200
#define DISCO_EFFECT_MAX_DURATION_MS 5000

// ========== Private Effect Type Enumeration ==========

enum disco_effect_type {
    DISCO_EFFECT_BREATHE = 0, // Breathing effect (all channels synchronized)
    DISCO_EFFECT_SOFT_PULSE = 1, // Soft pulse (fast rise, slow fall)
    DISCO_EFFECT_WARM_FADE = 2, // Warm fade (alternating channels)
    DISCO_EFFECT_COOL_FADE = 3, // Cool fade (alternating channels, reversed)
    DISCO_EFFECT_MOONLIGHT = 4, // Moonlight effect (very slow breathing)
    DISCO_EFFECT_RAINBOW = 5, // Rainbow cycle (channel-offset sine waves)
    DISCO_EFFECT_STROBE = 6, // Strobe (channel-by-channel flash)
    DISCO_EFFECT_RANDOM_FLASH = 7, // Random flash (channels flash randomly)

    DISCO_EFFECT_COUNT,
};

// ========== Private Runtime State ==========

static struct {
    uint32_t effect_start_ms; // Current effect start time
    uint32_t effect_duration_ms; // Current effect duration
    uint8_t current_effect; // Current effect type
    uint32_t random_seed; // Random number seed

    // Transition state
    bool in_transition; // Whether currently transitioning
    uint32_t transition_start_ms; // Transition start time
    led_color_t prev_color; // Previous effect's final color
    led_color_t next_color; // Next effect's initial color
} disco_runtime = { 0 };

// ========== Effect Function Declarations ==========

static void disco_effect_breathe(led_color_t color, uint32_t phase_ms, uint32_t duration_ms);
static void disco_effect_soft_pulse(led_color_t color, uint32_t phase_ms, uint32_t duration_ms);
static void disco_effect_warm_fade(led_color_t color, uint32_t phase_ms, uint32_t duration_ms);
static void disco_effect_cool_fade(led_color_t color, uint32_t phase_ms, uint32_t duration_ms);
static void disco_effect_moonlight(led_color_t color, uint32_t phase_ms, uint32_t duration_ms);
static void disco_effect_rainbow(led_color_t color, uint32_t phase_ms, uint32_t duration_ms);
static void disco_effect_strobe(led_color_t color, uint32_t phase_ms, uint32_t duration_ms);
static void disco_effect_random_flash(led_color_t color, uint32_t phase_ms, uint32_t duration_ms);

typedef void (*disco_effect_fn)(led_color_t, uint32_t, uint32_t);

static const disco_effect_fn DISCO_EFFECTS[] = {
    disco_effect_breathe,   disco_effect_soft_pulse, disco_effect_warm_fade, disco_effect_cool_fade,
    disco_effect_moonlight, disco_effect_rainbow,    disco_effect_strobe,    disco_effect_random_flash,
};

// ========== Random Number Generator ==========

static uint32_t disco_next_random(uint32_t* seed)
{
    *seed = *seed * 1103515245 + 12345;
    return (*seed / 65536) % 32768;
}

// ========== Public Interface ==========

int led_disco_init()
{
    // Initialize random seed from high-resolution timer
    disco_runtime.random_seed = (uint32_t)(esp_timer_get_time() & 0xFFFFFFFF);
    disco_runtime.effect_start_ms = bo_timer_uptime_ms();

    // Randomly select first effect
    disco_runtime.current_effect = disco_next_random(&disco_runtime.random_seed) % DISCO_EFFECT_COUNT;

    // Randomly select effect duration
    uint32_t rand = disco_next_random(&disco_runtime.random_seed);
    disco_runtime.effect_duration_ms
        = DISCO_EFFECT_MIN_DURATION_MS + (rand % (DISCO_EFFECT_MAX_DURATION_MS - DISCO_EFFECT_MIN_DURATION_MS));

    // Not in transition initially
    disco_runtime.in_transition = false;

    ESP_LOGI(TAG, "Disco mode initialized. First effect: %u, duration: %u ms", disco_runtime.current_effect,
             disco_runtime.effect_duration_ms);

    return 0;
}

void led_disco_drive(time_t utc_now, led_color_t color)
{
    (void)utc_now; // Unused, disco mode uses uptime instead of wall time

    uint32_t now_ms = bo_timer_uptime_ms();

    // Handle transition state
    if (disco_runtime.in_transition) {
        uint32_t transition_elapsed = now_ms - disco_runtime.transition_start_ms;

        if (transition_elapsed >= DISCO_TRANSITION_DURATION_MS) {
            // Transition complete, start new effect
            disco_runtime.in_transition = false;
            disco_runtime.effect_start_ms = now_ms;

            ESP_LOGI(TAG, "Transition complete, now rendering effect %u", disco_runtime.current_effect);
        }
        else {
            // Perform linear crossfade interpolation
            float t = (float)transition_elapsed / (float)DISCO_TRANSITION_DURATION_MS;

            for (size_t ch = 0; ch < led_channel_count(); ch++) {
                float blended
                    = (float)disco_runtime.prev_color[ch] * (1.0f - t) + (float)disco_runtime.next_color[ch] * t;
                color[ch] = (led_brightness_t)blended;
            }
            return;
        }
    }

    // Check if current effect has finished
    uint32_t effect_elapsed = now_ms - disco_runtime.effect_start_ms;

    if (effect_elapsed >= disco_runtime.effect_duration_ms) {
        // Save current effect's final color
        DISCO_EFFECTS[disco_runtime.current_effect](disco_runtime.prev_color, disco_runtime.effect_duration_ms,
                                                    disco_runtime.effect_duration_ms);

        // Select next effect
        uint8_t next_effect = disco_next_random(&disco_runtime.random_seed) % DISCO_EFFECT_COUNT;

        // Calculate next effect's initial color
        DISCO_EFFECTS[next_effect](disco_runtime.next_color, 0,
                                   DISCO_EFFECT_MIN_DURATION_MS // Any duration works for initial frame
        );

        // Update effect and duration
        disco_runtime.current_effect = next_effect;
        uint32_t rand = disco_next_random(&disco_runtime.random_seed);
        disco_runtime.effect_duration_ms
            = DISCO_EFFECT_MIN_DURATION_MS + (rand % (DISCO_EFFECT_MAX_DURATION_MS - DISCO_EFFECT_MIN_DURATION_MS));

        // Start transition
        disco_runtime.in_transition = true;
        disco_runtime.transition_start_ms = now_ms;

        ESP_LOGI(TAG, "Effect switch: -> effect %u, duration: %u ms (transition %u ms)", next_effect,
                 disco_runtime.effect_duration_ms, DISCO_TRANSITION_DURATION_MS);

        // Render first frame of crossfade (t=0, so prev_color)
        memcpy(color, disco_runtime.prev_color, sizeof(led_color_t));
        return;
    }

    // Render current effect normally
    DISCO_EFFECTS[disco_runtime.current_effect](color, effect_elapsed, disco_runtime.effect_duration_ms);
}

// ========== Effect Implementations ==========

// Helper: Scale brightness to DISCO_MAX_BRIGHTNESS
static inline led_brightness_t scale_brightness(float normalized_value)
{
    if (normalized_value < 0.0f)
        normalized_value = 0.0f;
    if (normalized_value > 1.0f)
        normalized_value = 1.0f;
    return (led_brightness_t)(normalized_value * DISCO_MAX_BRIGHTNESS);
}

// Effect 1: Breathing (sine wave, all channels synchronized)
static void disco_effect_breathe(led_color_t color, uint32_t phase_ms, uint32_t duration_ms)
{
    float progress = (float)phase_ms / (float)duration_ms;
    // Use absolute sine for more dramatic effect: goes from 0 to 1 and back
    float breathe = fabsf(sinf(progress * 2.0f * M_PI));
    led_brightness_t brightness = scale_brightness(breathe);

    for (size_t ch = 0; ch < led_channel_count(); ch++) {
        color[ch] = brightness;
    }
}

// Effect 2: Soft pulse (fast rise, slow fall, all channels synchronized)
static void disco_effect_soft_pulse(led_color_t color, uint32_t phase_ms, uint32_t duration_ms)
{
    float progress = (float)phase_ms / (float)duration_ms;
    float pulse;

    if (progress < 0.2f) {
        // Very fast rise: 0 to 20% of time, from 0 to 1
        pulse = progress / 0.2f;
    }
    else {
        // Slow fall: 20% to 100% of time, from 1 to 0
        pulse = 1.0f - (progress - 0.2f) / 0.8f;
    }

    // Cubic easing for more dramatic effect
    pulse = pulse * pulse * pulse;
    led_brightness_t brightness = scale_brightness(pulse);

    for (size_t ch = 0; ch < led_channel_count(); ch++) {
        color[ch] = brightness;
    }
}

// Effect 3: Warm fade (alternating channels, high to low)
static void disco_effect_warm_fade(led_color_t color, uint32_t phase_ms, uint32_t duration_ms)
{
    float progress = (float)phase_ms / (float)duration_ms;

    // From 100% to 0%, very dramatic
    float brightness_high = (1.0f - progress); // 100% -> 0%
    float brightness_low = (1.0f - progress) * 0.5f; // 50% -> 0% (dimmer channel)

    led_brightness_t high = scale_brightness(brightness_high);
    led_brightness_t low = scale_brightness(brightness_low);

    size_t ch_count = led_channel_count();
    for (size_t ch = 0; ch < ch_count; ch++) {
        // Alternate pattern, or all same if only 1 channel
        if (ch_count <= 1 || ch % 2 == 0) {
            color[ch] = high;
        }
        else {
            color[ch] = low;
        }
    }
}

// Effect 4: Cool fade (alternating channels, low to high, reversed)
static void disco_effect_cool_fade(led_color_t color, uint32_t phase_ms, uint32_t duration_ms)
{
    float progress = (float)phase_ms / (float)duration_ms;

    // From 0% to 100%, very dramatic (opposite of warm fade)
    float brightness_high = progress; // 0% -> 100%
    float brightness_low = progress * 0.5f; // 0% -> 50% (dimmer channel)

    led_brightness_t high = scale_brightness(brightness_high);
    led_brightness_t low = scale_brightness(brightness_low);

    size_t ch_count = led_channel_count();
    for (size_t ch = 0; ch < ch_count; ch++) {
        // Alternate pattern, or all same if only 1 channel
        if (ch_count <= 1 || ch % 2 == 0) {
            color[ch] = high;
        }
        else {
            color[ch] = low;
        }
    }
}

// Effect 5: Moonlight (slow breathing with full range 0-100%)
static void disco_effect_moonlight(led_color_t color, uint32_t phase_ms, uint32_t duration_ms)
{
    float progress = (float)phase_ms / (float)duration_ms;

    // Apply smoothstep for smooth transitions
    float t = progress;
    float smoothstep = 3.0f * t * t - 2.0f * t * t * t;

    // Sine wave with smoothstep, full range [0, 1]
    float moonlight = (sinf(smoothstep * 2.0f * M_PI) + 1.0f) / 2.0f;

    led_brightness_t brightness = scale_brightness(moonlight);

    for (size_t ch = 0; ch < led_channel_count(); ch++) {
        color[ch] = brightness;
    }
}

// Effect 6: Rainbow cycle (each channel offset sine wave)
static void disco_effect_rainbow(led_color_t color, uint32_t phase_ms, uint32_t duration_ms)
{
    float progress = (float)phase_ms / (float)duration_ms;
    size_t ch_count = led_channel_count();

    // Each channel gets a phase-offset sine wave
    for (size_t ch = 0; ch < ch_count; ch++) {
        // Channel offset: 2π * ch / ch_count
        float phase_offset = (float)ch * 2.0f * M_PI / (float)ch_count;

        // Sine wave with offset, range [0, 1]
        float wave = (sinf(progress * 2.0f * M_PI + phase_offset) + 1.0f) / 2.0f;

        color[ch] = scale_brightness(wave);
    }
}

// Effect 7: Strobe (each channel flashes in sequence)
static void disco_effect_strobe(led_color_t color, uint32_t phase_ms, uint32_t duration_ms)
{
    size_t ch_count = led_channel_count();
    float progress = (float)phase_ms / (float)duration_ms;

    // Cycle through channels: each gets ~500ms of attention
    float cycle_time = progress * (float)ch_count; // 0 to ch_count over duration
    uint8_t active_ch = (uint8_t)cycle_time % ch_count;
    float strobe_phase = fmodf(cycle_time, 1.0f); // 0 to 1 within current channel

    // Sharp on/off strobe: 0-0.3 = off, 0.3-0.7 = on, 0.7-1.0 = off
    float brightness = (strobe_phase > 0.2f && strobe_phase < 0.8f) ? 1.0f : 0.0f;

    for (size_t ch = 0; ch < ch_count; ch++) {
        if (ch == active_ch) {
            color[ch] = scale_brightness(brightness);
        }
        else {
            color[ch] = 0; // Other channels off
        }
    }
}

// Effect 8: Random flash (each channel flashes independently with pseudo-random pattern)
static void disco_effect_random_flash(led_color_t color, uint32_t phase_ms, uint32_t duration_ms)
{
    size_t ch_count = led_channel_count();

    // Use disco_runtime.random_seed to generate per-channel patterns
    uint32_t temp_seed = disco_runtime.random_seed ^ phase_ms; // Mix in time for variation

    for (size_t ch = 0; ch < ch_count; ch++) {
        // Generate unique pattern per channel
        uint32_t ch_seed = temp_seed ^ (ch * 12345);
        uint32_t rand_val = disco_next_random(&ch_seed);

        // Flash pattern: if random value modulo period is in "on" range
        uint32_t flash_period = 1000 + (rand_val % 1000); // 1-2 second periods
        uint32_t phase_in_period = ((uint32_t)phase_ms) % flash_period;

        // 30% on time, 70% off time
        float brightness = (phase_in_period < (flash_period / 3)) ? 1.0f : 0.1f;

        color[ch] = scale_brightness(brightness);
    }
}
