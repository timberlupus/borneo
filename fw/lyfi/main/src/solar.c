/**
 * @file solar.c
 * @brief Calculate sunrise and sunset times using time_t
 *
 * This program implements a simplified algorithm based on Jean Meeus's
 * "Astronomical Algorithms" to calculate sunrise and sunset times,
 * using the standard time_t type for date input.
 */

#include <math.h>
#include <stdbool.h>
#include <time.h>
#include <sys/errno.h>

#include <esp_check.h>
#include <esp_log.h>

#include <borneo/algo/astronomy.h>

#include "solar.h"

#define TAG "solar"

static int solar_day_of_year(const struct tm* tm_local);

typedef struct {
    float altitude_deg;
    float brightness;
} solar_altitude_lux_t;

static const solar_altitude_lux_t solar_lux_table[] = {
    { 0.0f, 0.0f },   { 15.0f, 0.25f }, { 30.0f, 0.50f }, { 45.0f, 0.70f },
    { 60.0f, 0.85f }, { 75.0f, 0.95f }, { 90.0f, 1.0f },
};

// Utility functions for angle conversions
static inline float deg_to_rad(float deg) { return deg * (float)M_PI / 180.0f; }

static inline float rad_to_deg(float rad) { return rad * 180.0f / (float)M_PI; }

static float solar_altitude_to_brightness_ratio(float altitude_deg)
{
    if (altitude_deg <= 0.0f) {
        return 0.0f;
    }
    if (altitude_deg >= 90.0f) {
        return 1.0f;
    }
    for (int i = 1; i < sizeof(solar_lux_table) / sizeof(solar_lux_table[0]); ++i) {
        if (altitude_deg < solar_lux_table[i].altitude_deg) {
            float x0 = solar_lux_table[i - 1].altitude_deg, y0 = solar_lux_table[i - 1].brightness;
            float x1 = solar_lux_table[i].altitude_deg, y1 = solar_lux_table[i].brightness;
            return y0 + (y1 - y0) * (altitude_deg - x0) / (x1 - x0);
        }
    }
    return 100.0f;
}

static float solar_time_for_altitude(float latitude, float decl, float noon, float altitude_deg, int afternoon)
{
    float lat_rad = deg_to_rad(latitude);
    float decl_rad = deg_to_rad(decl);
    float h_rad = deg_to_rad(altitude_deg);

    float cos_omega = (sinf(h_rad) - sinf(lat_rad) * sinf(decl_rad)) / (cosf(lat_rad) * cosf(decl_rad));
    if (cos_omega < -1.0f || cos_omega > 1.0f)
        return -1.0f; // Not exists

    float omega_deg = rad_to_deg(acosf(cos_omega));
    if (afternoon) {
        return noon + omega_deg / 15.0f;
    }
    else {
        return noon - omega_deg / 15.0f;
    }
}

/**
 * @brief Calculates the day of the year for a given date.
 * @return The day of the year (1-365 or 366 for leap years).
 */
int solar_day_of_year(const struct tm* tm_local)
{
    static const int days_before_month[] = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
    int doy = days_before_month[tm_local->tm_mon] + tm_local->tm_mday;
    // Add one day for leap years after February
    if (tm_local->tm_mon > 1) {
        if ((tm_local->tm_year % 4 == 0 && tm_local->tm_year % 100 != 0) || (tm_local->tm_year % 400 == 0)) {
            doy += 1;
        }
    }
    return doy;
}

float solar_calculate_local_tz_offset(const struct tm* tm_local)
{
    // Convert to time_t, accounting for local timezone
    time_t local_time = mktime(tm_local);

    // Get UTC time
    struct tm tm_utc;
    gmtime_r(&local_time, &tm_utc);
    time_t utc_time = mktime(&tm_utc);

    // Calculate timezone offset in hours
    return (float)(local_time - utc_time) / 3600.0f;
}

int solar_calculate_sunrise_sunset(float latitude, float longitude, time_t utc_now, float target_tz_offset,
                                   float local_tz_offset, const struct tm* tm_local, float* sunrise, float* noon,
                                   float* sunset, float* decl_out)
{
    // Validate input parameters
    if (latitude < -90.0f || latitude > 90.0f) {
        ESP_LOGE(TAG, "Latitude must be between -90 and 90 degrees");
        return -EINVAL;
    }
    if (longitude < -180.0f || longitude > 180.0f) {
        ESP_LOGE(TAG, "Longitude must be between -180 and 180 degrees");
        return -EINVAL;
    }

    time_t target_now = utc_now + (time_t)(roundf(target_tz_offset * 3600.0f));
    struct tm target_tm;
    gmtime_r(&target_now, &target_tm);

    int doy = solar_day_of_year(&target_tm);

    // Calculate solar declination angle (simplified)
    float decl = 23.45f * sinf(deg_to_rad(360.0f * (284 + doy) / 365.0f));
    if (decl_out != NULL) {
        *decl_out = decl;
    }

    float lat_rad = deg_to_rad(latitude);
    float decl_rad = deg_to_rad(decl);

    float cos_omega = -tanf(lat_rad) * tanf(decl_rad);
    if (cos_omega > 1.0f) {
        cos_omega = 1.0f;
    }
    if (cos_omega < -1.0f) {
        cos_omega = -1.0f;
    }
    float omega = acosf(cos_omega); // Solar hour angle for sunrise/sunset (radians)

    // Check for polar day/night conditions
    if (cos_omega >= 1.0f) {
        ESP_LOGE(TAG, "Polar night condition (sun does not rise)");
        return -ENODATA;
    }
    if (cos_omega <= -1.0f) {
        ESP_LOGE(TAG, "Midnight sun condition (sun does not set)");
        return -ENODATA;
    }

    // Convert omega to time (hours)
    float daylight_hours = rad_to_deg(omega) / 15.0f * 2.0f;

    float noon_target = 12.0 + (local_tz_offset * 15.0 - longitude) / 15.0;
    float sunrise_target = noon_target - daylight_hours / 2.0f;
    float sunset_target = noon_target + daylight_hours / 2.0f;

    *noon = noon_target - target_tz_offset + local_tz_offset;
    *sunrise = sunrise_target - target_tz_offset + local_tz_offset;
    *sunset = sunset_target - target_tz_offset + local_tz_offset;

    // Normalize times to 0-24 hour range
    while (*noon < 0.0f)
        *noon += 24.0f;
    while (*noon >= 24.0f)
        *noon -= 24.0f;
    while (*sunrise < 0.0f)
        *sunrise += 24.0f;
    while (*sunrise >= 24.0f)
        *sunrise -= 24.0f;
    while (*sunset < 0.0f)
        *sunset += 24.0f;
    while (*sunset >= 24.0f)
        *sunset -= 24.0f;

    return 0;
}

/**
 * @brief Clamps a time value to the range [0, 24].
 * @param time The time value to clamp (in hours).
 * @return The clamped time value.
 */
float solar_clamp_time(float time)
{
    if (time < 0.0f) {
        return 0.0f;
    }
    if (time > 24.0f) {
        return 24.0f;
    }
    return time;
}
int solar_generate_instants(float latitude, float decl, float sunrise, float noon, float sunset,
                            struct solar_instant* instants)
{
    if (instants == NULL) {
        return -EINVAL;
    }

    static const float altitudes[] = {
        0.0f, 15.0f, 30.0f, 45.0f, 60.0f, 75.0f, 90.0f, 75.0f, 60.0f, 45.0f, 30.0f, 15.0f, 0.0f,
    };
    static const int count = sizeof(altitudes) / sizeof(altitudes[0]);

    int idx = 0;
    for (int i = 0; i < count; ++i) {
        int afternoon = (i > 6) ? 1 : 0;
        float t = solar_time_for_altitude(latitude, decl, noon, altitudes[i], afternoon);
        float brightness = solar_altitude_to_brightness_ratio(altitudes[i]);
        if (t < 0.0f) {
            if (idx > 0) {
                instants[idx].time = instants[idx - 1].time;
                instants[idx].brightness = instants[idx - 1].brightness;
            }
            else {
                instants[idx].time = sunrise;
                instants[idx].brightness = 0.0f;
            }
        }
        else {
            instants[idx].time = t;
            instants[idx].brightness = brightness;
        }
        idx++;
    }

    return 0;
}