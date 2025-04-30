#pragma once

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

struct geo_location {
    float lat;
    float lng;
};

/// @brief Convert Unix time to Julian date.
/// @param t time_t
/// @return Julian date
inline float astronomy_julian_date(time_t t)
{
    // Calculate days since Unix epoch (integer division)
    long days = t / 86400;
    // Calculate remaining seconds (fractional day)
    float fractional_day = (float)(t % 86400) / 86400.0f;
    // Add Julian Date offset for Unix epoch (Jan 1, 1970)
    return (float)days + fractional_day + 2440587.5f;
}

#ifdef __cplusplus
}
#endif
