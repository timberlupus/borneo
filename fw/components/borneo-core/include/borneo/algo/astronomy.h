#pragma once

#include <time.h>

#ifdef __cplusplus
extern "C" {
#endif

struct geo_location {
    double lat;
    double lng;
};

/// @brief Convert Unix time to Julian date.
/// @param t time_t
/// @return Julian date
inline double astronomy_julian_date(time_t t) { return (t / 86400.0L + 2440587.5); }

#ifdef __cplusplus
}
#endif
