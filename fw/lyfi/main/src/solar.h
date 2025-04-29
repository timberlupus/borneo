#pragma once

#include <time.h>

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
    double brightness; // Brightness value (0 to 1.0)
};

/**
 * @brief Calculates the timezone offset in hours for a given date.
 * @return The timezone offset in hours.
 */
double solar_calculate_timezone_offset(const struct tm* tm_local);

/**
 * @brief Calculate sunrise and sunset times
 * @param latitude Location latitude (-90 to 90)
 * @param longitude Location longitude (-180 to 180)
 * @param tm_local Local time
 * @param[out] sunrise Calculated sunrise time (hours, 0-24)
 * @param[out] sunset Calculated sunset time (hours, 0-24)
 * @return 0 on success, negative errno value on failure
 *
 * @note Possible errors:
 *  -EINVAL: Invalid input parameters
 *  -ENODATA: Polar night/midnight sun condition
 *  -EFAULT: Time calculation error
 */
int solar_calculate_sunrise_sunset(double latitude, double longitude, double timezone_offset, const struct tm* tm_local,
                                   double* sunrise, double* sunset);

/**
 * @brief Generates key points for solar brightness throughout the day.
 * @param sunrise The sunrise time in hours.
 * @param sunset The sunset time in hours.
 * @param instants Array to store the generated instants.
 * @param max_points Maximum number of key points to generate.
 * @return The number of key points generated.
 */
int solar_generate_instants(double sunrise, double sunset, struct solar_instant* instants);

#ifdef __cplusplus
}
#endif