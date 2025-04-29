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
static bool is_valid_date(int year, int month, int day);

/**
 * @brief Validate a date
 * @param year Year (1900-3000)
 * @param month Month (1-12)
 * @param day Day of month
 * @return true if date is valid, false otherwise
 */
static bool is_valid_date(int year, int month, int day)
{
    if (year < 1900 || year > 3000)
        return false;
    if (month < 1 || month > 12)
        return false;

    static const int days_in_month[] = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 };
    int days = days_in_month[month - 1];

    // Handle February in leap years
    if (month == 2 && ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0))) {
        days = 29;
    }

    return day >= 1 && day <= days;
}

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
 * @param year The year (e.g., 2025).
 * @param month The month (1-12).
 * @param day The day of the month (1-31).
 * @return The day of the year (1-365 or 366 for leap years).
 */
int solar_day_of_year(int year, int month, int day)
{
    static const int days_before_month[] = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };
    int doy = days_before_month[month - 1] + day;
    // Add one day for leap years after February
    if (month > 2) {
        if ((year % 4 == 0 && year % 100 != 0) || (year % 400 == 0))
            doy += 1;
    }
    return doy;
}

double solar_calculate_timezone_offset(int year, int month, int day)
{
    // Create a tm structure for local time at noon
    struct tm tm_local = { 0 };
    tm_local.tm_year = year - 1900;
    tm_local.tm_mon = month - 1;
    tm_local.tm_mday = day;
    tm_local.tm_hour = 12; // Noon as reference time
    tm_local.tm_isdst = -1; // Let system determine daylight saving time

    // Convert to time_t, accounting for local timezone
    time_t local_time = mktime(&tm_local);

    // Get UTC time
    struct tm tm_utc;
    gmtime_r(&local_time, &tm_utc);
    time_t utc_time = mktime(&tm_utc);

    // Calculate timezone offset in hours
    return difftime(local_time, utc_time) / 3600.0;
}

int solar_calculate_sunrise_sunset(double latitude, double longitude, int timezone_offset, int year, int month, int day,
                                   double* sunrise, double* sunset)
{
    // Validate input parameters
    if (latitude < -90.0 || latitude > 90.0) {
        strcpy(error_msg, "Latitude must be between -90 and 90 degrees");
        return -EINVAL;
    }
    if (longitude < -180.0 || longitude > 180.0) {
        ESP_LOGE(TAG, "Longitude must be between -180 and 180 degrees");
        return -EINVAL;
    }
    if (!is_valid_date(year, month, day)) {
        ESP_LOGE(TAG, "Invalid date provided");
        return -EINVAL;
    }

    int doy = solar_day_of_year(year, month, day);

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

/**
 * @brief Generates key points for solar brightness throughout the day.
 * @param sunrise The sunrise time in hours.
 * @param sunset The sunset time in hours.
 * @param instants Array to store the generated instants.
 * @param max_points Maximum number of key points to generate.
 * @return The number of key points generated.
 */
int solar_generate_instants(double sunrise, double sunset, struct solar_instant* instants)
{
    double noon = solar_calculate_noon(sunrise, sunset);
    const double twilight = 0.5; // 30 minutes for civil twilight

    double sunrise_twilight = solar_clamp_time(sunrise - twilight);
    double sunrise_plus_1h = solar_clamp_time(sunrise + 1.0);
    double noon_plus_3h = solar_clamp_time(noon + 3.0);
    double sunset_minus_1h = solar_clamp_time(sunset - 1.0);
    double sunset_plus_twilight = solar_clamp_time(sunset + twilight);

    size_t idx = 0;
    instants[idx++] = (struct solar_instant) { sunrise_twilight, 0 }; // Start of dawn
    instants[idx++] = (struct solar_instant) { sunrise, 800 }; // Sunrise
    instants[idx++] = (struct solar_instant) { sunrise_plus_1h, 900 }; // 1 hour after sunrise
    instants[idx++] = (struct solar_instant) { noon, 1000 }; // Noon
    instants[idx++] = (struct solar_instant) { noon_plus_3h, 950 }; // 3 hours after noon
    instants[idx++] = (struct solar_instant) { sunset_minus_1h, 850 }; // 1 hour before sunset
    instants[idx++] = (struct solar_instant) { sunset, 800 }; // Sunset
    instants[idx++] = (struct solar_instant) { sunset_plus_twilight, 0 }; // End of dusk

    return idx;
}