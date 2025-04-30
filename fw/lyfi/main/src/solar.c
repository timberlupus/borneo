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
#
#include <borneo/algo/astronomy.h>

#include "solar.h"

#define TAG "solar"

static time_t solar_offset_time_by_hours(time_t base_time, double offset_hours);
static int solar_day_of_year(const struct tm* tm_local);

/**
 * @brief Offsets a given time by a specified number of hours.
 * @param base_time The base time to offset (in seconds since epoch).
 * @param offset_hours The number of hours to offset (can be fractional).
 * @return The adjusted time as a time_t value.
 */
time_t solar_offset_time_by_hours(time_t base_time, double offset_hours)
{
    struct tm tm_time;
    localtime_r(&base_time, &tm_time);

    int offset_seconds = (int)(offset_hours * 3600.0);
    base_time += offset_seconds;

    // Re-normalize the time
    localtime_r(&base_time, &tm_time);
    return mktime(&tm_time);
}

// Utility functions for angle conversions
double deg_to_rad(double deg) { return deg * M_PI / 180.0; }

double rad_to_deg(double rad) { return rad * 180.0 / M_PI; }

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

double solar_calculate_timezone_offset(const struct tm* tm_local)
{
    // Convert to time_t, accounting for local timezone
    time_t local_time = mktime(tm_local);

    // Get UTC time
    struct tm tm_utc;
    gmtime_r(&local_time, &tm_utc);
    time_t utc_time = mktime(&tm_utc);

    // Calculate timezone offset in hours
    return difftime(local_time, utc_time) / 3600.0;
}

int solar_calculate_sunrise_sunset(double latitude, double longitude, double timezone_offset, const struct tm* tm_local,
                                   double* sunrise, double* sunset)
{
    // Validate input parameters
    if (latitude < -90.0 || latitude > 90.0) {
        ESP_LOGE(TAG, "Latitude must be between -90 and 90 degrees");
        return -EINVAL;
    }
    if (longitude < -180.0 || longitude > 180.0) {
        ESP_LOGE(TAG, "Longitude must be between -180 and 180 degrees");
        return -EINVAL;
    }

    int doy = solar_day_of_year(tm_local);

    // Calculate solar declination angle (simplified)
    double decl = 23.45 * sin(deg_to_rad(360.0 * (284 + doy) / 365.0));

    double lat_rad = deg_to_rad(latitude);
    double decl_rad = deg_to_rad(decl);

    double cos_omega = -tan(lat_rad) * tan(decl_rad);
    if (cos_omega > 1.0) {
        cos_omega = 1.0;
    }
    if (cos_omega < -1.0) {
        cos_omega = -1.0;
    }
    double omega = acos(cos_omega); // Solar hour angle for sunrise/sunset (radians)

    // Check for polar day/night conditions
    if (cos_omega >= 1.0) {
        ESP_LOGE(TAG, "Polar night condition (sun does not rise)");
        return -ENODATA;
    }
    if (cos_omega <= -1.0) {
        ESP_LOGE(TAG, "Midnight sun condition (sun does not set)");
        return -ENODATA;
    }

    // Convert omega to time (hours)
    double daylight_hours = rad_to_deg(omega) / 15.0 * 2.0;

    // Calculate true solar noon (local time)
    double solar_noon = 12.0 + (timezone_offset * 15.0 - longitude) / 15.0;

    *sunrise = solar_noon - daylight_hours / 2.0;
    *sunset = solar_noon + daylight_hours / 2.0;

    // Normalize times to 0-24 hour range
    while (*sunrise < 0)
        *sunrise += 24;
    while (*sunrise >= 24)
        *sunrise -= 24;
    while (*sunset < 0)
        *sunset += 24;
    while (*sunset >= 24)
        *sunset -= 24;

    return 0;
}

/**
 * @brief Calculates the solar noon time.
 * @param sunrise The sunrise time in hours.
 * @param sunset The sunset time in hours.
 * @return The solar noon time in hours.
 */
double solar_calculate_noon(double sunrise, double sunset) { return (sunrise + sunset) / 2.0; }

/**
 * @brief Clamps a time value to the range [0, 24].
 * @param time The time value to clamp (in hours).
 * @return The clamped time value.
 */
double solar_clamp_time(double time)
{
    if (time < 0) {
        return 0;
    }
    if (time > 24) {
        return 24;
    }
    return time;
}

int solar_generate_instants(double sunrise, double sunset, struct solar_instant* instants)
{
    double noon = solar_calculate_noon(sunrise, sunset);

    instants[SOLAR_INDEX_SUNRISE] = (struct solar_instant) { sunrise, 0 };
    instants[SOLAR_INDEX_AFTER_SUNRISE] = (struct solar_instant) { solar_clamp_time(sunrise + 0.5), 0.2 };
    instants[SOLAR_INDEX_MORNING_MAX_SLOPE] = (struct solar_instant) { solar_clamp_time(noon - 1.5), 0.6 };
    instants[SOLAR_INDEX_NOON_MINUS_1HOUR] = (struct solar_instant) { solar_clamp_time(noon - 1.0), 0.95 };
    instants[SOLAR_INDEX_NOON] = (struct solar_instant) { noon, 1.0 };
    instants[SOLAR_INDEX_NOON_PLUS_1HOUR] = (struct solar_instant) { solar_clamp_time(noon + 1.0), 0.95 };
    instants[SOLAR_INDEX_AFTERNOON_MAX_SLOPE] = (struct solar_instant) { solar_clamp_time(sunset - 1.5), 0.5 };
    instants[SOLAR_INDEX_SUNSET] = (struct solar_instant) { sunset, 0 };

    return 0;
}