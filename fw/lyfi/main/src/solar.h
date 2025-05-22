#pragma once

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

#define SOLAR_INSTANTS_COUNT 13

/**
 * @brief Structure representing a key point in the solar day.
 */
struct solar_instant {
    float time; // Time in hours (e.g., 6.5 represents 6:30)
    float brightness; // Brightness value (0 to 1.0)
};

/**
 * @brief Calculates the timezone offset in hours for a given date.
 * @param tm_local Local time
 * @return The timezone offset in hours.
 */
float solar_calculate_local_tz_offset(const struct tm* tm_local);

/**
 * @brief Calculate sunrise and sunset times
 * @param latitude Location latitude (-90 to 90)
 * @param longitude Location longitude (-180 to 180)
 * @param utc_now UTC time
 * @param target_tz_offset Target timezone offset in hours
 * @param local_tz_offset Local timezone offset in hours
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
int solar_calculate_sunrise_sunset(float latitude, float longitude, time_t utc_now, float target_tz_offset,
                                   float local_tz_offset, const struct tm* tm_local, float* sunrise, float* noon,
                                   float* sunset, float* decl_out);

/**
 * @brief Generates key points for solar brightness throughout the day.
 * @return 0 on success
 */
int solar_generate_instants(float latitude, float decl, float sunrise, float noon, float sunset,
                            struct solar_instant* instants);

#ifdef __cplusplus
}
#endif