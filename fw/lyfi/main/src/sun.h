#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Calculate sunrise and sunset times
 * @param latitude Observer's latitude in degrees (N positive)
 * @param longitude Observer's longitude in degrees (E positive)
 * @param t Time in time_t format (only date portion used)
 * @param[out] sunrise Pointer to store sunrise time (UTC hours)
 * @param[out] sunset Pointer to store sunset time (UTC hours)
 *
 * Calculates approximate sunrise and sunset times in UTC for given location and date.
 */
void sun_compute_sunrise_sunset(double latitude, double longitude, time_t t, double* sunrise, double* sunset);

#ifdef __cplusplus
}
#endif