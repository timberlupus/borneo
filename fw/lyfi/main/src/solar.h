#pragma once

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

enum solar_instants_enum {
    SOLAR_INDEX_SUNRISE = 0,
    SOLAR_INDEX_AFTER_SUNRISE,
    SOLAR_INDEX_MORNING_MAX_SLOPE,
    SOLAR_INDEX_NOON_MINUS_1HOUR,
    SOLAR_INDEX_NOON,
    SOLAR_INDEX_NOON_PLUS_1HOUR,
    SOLAR_INDEX_AFTERNOON_MAX_SLOPE,
    SOLAR_INDEX_SUNSET,

    SOLAR_INSTANTS_COUNT,
};

/**
 * @brief Structure representing a key point in the solar day.
 */
struct solar_instant {
    float time; // Time in hours (e.g., 6.5 represents 6:30)
    float brightness; // Brightness value (0 to 1.0)
};

/**
 * @brief Calculates the timezone offset in hours for a given date.
 * @return The timezone offset in hours.
 */
float solar_calculate_timezone_offset(const struct tm* tm_local);

/**
 * @brief Calculate sunrise and sunset times
 * @param latitude Location latitude (-90 to 90)
 * @param longitude Location longitude (-180 to 180)
 * @param timezone_offset Timezone offset in hours
 * @param tm_local Local time
 * @param[out] sunrise Calculated sunrise time (hours, 0-24)
 * @param[out] noon Calculated solar noon time (hours, 0-24)
 * @param[out] sunset Calculated sunset time (hours, 0-24)
 * @return 0 on success, negative errno value on failure
 *
 * @note Possible errors:
 *  -EINVAL: Invalid input parameters
 *  -ENODATA: Polar night/midnight sun condition
 *  -EFAULT: Time calculation error
 */
int solar_calculate_sunrise_sunset(float latitude, float longitude, float timezone_offset, const struct tm* tm_local,
                                   float* sunrise, float* noon, float* sunset);

/**
 * @brief Generates key points for solar brightness throughout the day.
 * @param sunrise The sunrise time in hours.
 * @param sunset The sunset time in hours.
 * @param instants Array to store the generated instants.
 * @return 0 on success
 */
int solar_generate_instants(float sunrise, float noon, float sunset, struct solar_instant* instants);

#ifdef __cplusplus
}
#endif