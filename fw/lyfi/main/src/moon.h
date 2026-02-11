#pragma once

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

#define MOON_INSTANTS_COUNT 6

/**
 * @brief Structure representing a key point in the moonlight cycle.
 */
struct moon_instant {
    float time; // Time in hours (e.g., 6.5 represents 6:30)
    float brightness; // Brightness value (0 to 1.0)
};

/**
 * @brief Calculate moon illumination fraction from Julian date.
 * @param jd Julian date
 * @return Illumination fraction (0.0 to 1.0)
 */
float moon_illumination(float jd);

/**
 * @brief Calculate moonrise and moonset times (simplified model).
 * @param latitude Location latitude (-90 to 90)
 * @param longitude Location longitude (-180 to 180)
 * @param utc_now UTC time
 * @param target_tz_offset Target timezone offset in hours
 * @param local_tz_offset Local timezone offset in hours
 * @param tm_local Local time
 * @param[out] moonrise Calculated moonrise time (hours, 0-24)
 * @param[out] moonset Calculated moonset time (hours, 0-24)
 * @param[out] decl_out Moon declination in degrees (optional)
 * @param[out] illum_out Moon illumination fraction (optional)
 * @return 0 on success, negative errno value on failure
 */
int moon_calculate_rise_set(float latitude, float longitude, time_t utc_now, float target_tz_offset,
                            float local_tz_offset, const struct tm* tm_local, float* moonrise, float* moonset,
                            float* decl_out, float* illum_out);

/**
 * @brief Generates key points for moon brightness throughout the night.
 * @param moonrise Moonrise time (hours, 0-24)
 * @param moonset Moonset time (hours, 0-24 or 24-48 when crossing midnight)
 * @param illumination Moon illumination fraction (0.0 to 1.0)
 * @param[out] instants Generated instants
 * @return 0 on success, negative errno value on failure
 */
int moon_generate_instants(float moonrise, float moonset, float illumination, struct moon_instant* instants);

#ifdef __cplusplus
}
#endif