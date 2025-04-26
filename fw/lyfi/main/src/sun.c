/**
 * @file sunrise_sunset.c
 * @brief Calculate sunrise and sunset times using time_t
 *
 * This program implements a simplified algorithm based on Jean Meeus's
 * "Astronomical Algorithms" to calculate sunrise and sunset times,
 * using the standard time_t type for date input.
 */

#include <math.h>
#include <time.h>

#include <borneo/algo/astronomy.h>

#define PI 3.14159265358979323846 /**< Pi constant */
#define SUN_ALTITUDE -0.833 /**< Standard altitude for sunrise/set (degrees) */
#define BEIJING_OFFSET 8.0 /**< Beijing timezone offset from UTC (hours) */

static void calculate_sun_position(double jd, double* declination, double* hour_angle);

/**
 * @brief Convert degrees to radians
 * @param deg Angle in degrees
 * @return Angle in radians
 */
inline static double deg2rad(double deg) { return deg * PI / 180.0; }

/**
 * @brief Convert radians to degrees
 * @param rad Angle in radians
 * @return Angle in degrees
 */
inline static double rad2deg(double rad) { return rad * 180.0 / PI; }

/**
 * @brief Calculate solar position (declination and hour angle)
 * @param jd Julian Day
 * @param[out] declination Pointer to store sun's declination (radians)
 * @param[out] hour_angle Pointer to store sun's hour angle (radians)
 *
 * Calculates the sun's declination and approximate hour angle for sunrise/sunset.
 */
void calculate_sun_position(double jd, double* declination, double* hour_angle)
{
    // Days since J2000.0
    double n = jd - 2451545.0;

    // Mean solar longitude (degrees)
    double L = fmod(280.460 + 0.9856474 * n, 360.0);
    if (L < 0)
        L += 360.0;

    // Mean anomaly (degrees)
    double g = fmod(357.528 + 0.9856003 * n, 360.0);
    if (g < 0)
        g += 360.0;
    g = deg2rad(g);

    // Ecliptic longitude
    double lambda = deg2rad(L + 1.915 * sin(g) + 0.020 * sin(2 * g));

    // Obliquity of the ecliptic
    double epsilon = deg2rad(23.439 - 0.0000004 * n);

    // Solar declination
    *declination = asin(sin(epsilon) * sin(lambda));

    // Hour angle for sunrise/sunset
    *hour_angle = acos((sin(deg2rad(SUN_ALTITUDE)) - sin(*declination) * sin(0)) / (cos(*declination) * cos(0)));
}

/**
 * @brief Computes sunrise and sunset times
 * @param latitude Observer's latitude in degrees (N positive)
 * @param longitude Observer's longitude in degrees (E positive)
 * @param t Time in time_t format (only date portion used)
 * @param[out] sunrise Pointer to store sunrise time (UTC hours)
 * @param[out] sunset Pointer to store sunset time (UTC hours)
 *
 * Computes approximate sunrise and sunset times in UTC for given location and date.
 */
void sun_compute_sunrise_sunset(double latitude, double longitude, time_t t, double* sunrise, double* sunset)
{
    // Convert to Julian Day
    double jd = astronomy_julian_date(t);

    // Get solar position
    double declination, hour_angle;
    calculate_sun_position(jd, &declination, &hour_angle);

    // Calculate hour angle for sunrise/sunset
    double latitude_rad = deg2rad(latitude);
    double ha = acos((cos(deg2rad(90 - SUN_ALTITUDE)) / (cos(latitude_rad) * cos(declination))
                      - tan(latitude_rad) * tan(declination)));

    // Convert to UTC time (hours)
    double longitude_h = longitude / 15.0;
    double t_corr = 0.0; // Equation of time correction (simplified)

    *sunrise = fmod(12.0 - rad2deg(ha) / 15.0 - t_corr - longitude_h + 24.0, 24.0);
    *sunset = fmod(12.0 + rad2deg(ha) / 15.0 - t_corr - longitude_h + 24.0, 24.0);
}