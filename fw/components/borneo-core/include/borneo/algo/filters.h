/** @file filters.h
 * @brief Signal filtering algorithms for sensor data processing
 *
 * This header provides various filtering functions to smooth sensor readings
 * and reduce noise in embedded systems.
 */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/** @brief Median filter for uint16_t arrays
 *
 * Sorts the buffer in-place and returns the median value.
 * Useful for removing outliers and impulse noise.
 *
 * @param buffer Pointer to the array of uint16_t values
 * @param buffer_size Number of elements in the buffer
 * @return The median value of the buffer
 */
uint16_t median_filter_u16(uint16_t* buffer, size_t buffer_size);

/** @brief Exponential Moving Average filter for int32_t values
 *
 * Applies EMA filtering using integer arithmetic to avoid floating point operations.
 * Formula: filtered = (alpha_num * current + (alpha_denom - alpha_num) * previous) / alpha_denom
 *
 * @param current The new input value
 * @param filtered Pointer to the filtered value (updated in-place)
 * @param alpha_num Numerator for alpha (e.g., 1 for alpha=0.1)
 * @param alpha_denom Denominator for alpha (e.g., 10 for alpha=0.1)
 * @return The updated filtered value
 */
int32_t ema_filter(int32_t current, int32_t* filtered, int alpha_num, int alpha_denom);

#ifdef __cplusplus
}
#endif