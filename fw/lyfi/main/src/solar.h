#pragma once

#ifdef __cplusplus
extern "C" {
#endif

enum solar_instants_enum {
    SOLAR_INDEX_SUNRISE_TWILIGHT = 0, ///< Start of dawn
    SOLAR_INDEX_SUNRISE, ///< Sunrise
    SOLAR_INDEX_SUNRISE_PLUS_1H, // 1 hour after sunrise
    SOLAR_INDEX_NOON, ///< Noon
    SOLAR_INDEX_NOON_PLUS_3H, ///< 3 hours after noon
    SOLAR_INDEX_SUNSET_MINUS_1H, ///< 1 hour before sunset
    SOLAR_INDEX_SUNSET, ///< Sunset
    SOLAR_INDEX_SUNSET_PLUS_TWILIGHT, ///< End of dusk

    SOLAR_INSTANTS_COUNT,
};

/**
 * @brief Structure representing a key point in the solar day.
 */
struct solar_instant {
    double time; // Time in hours (e.g., 6.5 represents 6:30)
    double brightness; // Brightness value (0 to 1000)
};

/**
 * @brief Calculates the day of the year for a given date.
 * @param year The year (e.g., 2025).
 * @param month The month (1-12).
 * @param day The day of the month (1-31).
 * @return The day of the year (1-365 or 366 for leap years).
 */
int solar_day_of_year(int year, int month, int day);

/**
 * @brief Calculates the timezone offset in hours for a given date.
 * @param year The year (e.g., 2025).
 * @param month The month (1-12).
 * @param day The day of the month (1-31).
 * @return The timezone offset in hours.
 */
double solar_calculate_timezone_offset(int year, int month, int day);

/**
 * @brief Calculate sunrise and sunset times
 * @param latitude Location latitude (-90 to 90)
 * @param longitude Location longitude (-180 to 180)
 * @param year Year
 * @param month Month (1-12)
 * @param day Day of month
 * @param[out] sunrise Calculated sunrise time (hours, 0-24)
 * @param[out] sunset Calculated sunset time (hours, 0-24)
 * @param[out] error_msg Buffer for error message
 * @return 0 on success, negative errno value on failure
 *
 * @note Possible errors:
 *  -EINVAL: Invalid input parameters
 *  -ENODATA: Polar night/midnight sun condition
 *  -EFAULT: Time calculation error
 */
int solar_calculate_sunrise_sunset(double latitude, double longitude, int timezone_offset, int year, int month, int day,
                                   double* sunrise, double* sunset);

#ifdef __cplusplus
}
#endif