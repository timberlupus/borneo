#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/**
 * @brief Structure representing a key point in the solar day.
 */
struct solar_instant {
    double time; // Time in hours (e.g., 6.5 represents 6:30)
    double brightness; // Brightness value (0 to 1000)
};

#ifdef __cplusplus
}
#endif