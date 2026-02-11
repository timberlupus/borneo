#include <borneo/algo/astronomy.h>

// Non-inline definition for linking
float astronomy_julian_date(time_t t)
{
    long days = t / 86400;
    float fractional_day = (float)(t % 86400) / 86400.0f;
    return (float)days + fractional_day + 2440587.5f;
}