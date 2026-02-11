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
float astronomy_julian_date(time_t t);

#ifdef __cplusplus
}
#endif
