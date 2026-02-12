/**
 * @file moon.c
 * @brief Calculate moonrise/moonset times and illumination using time_t
 *
 * This program implements a simplified algorithm to estimate the moon's
 * position and illumination for nightly brightness simulation.
 */

#include <math.h>
#include <stdbool.h>
#include <time.h>
#include <sys/errno.h>

#include <esp_check.h>
#include <esp_log.h>

#include <borneo/algo/astronomy.h>

#include "moon.h"

#define TAG "moon"

#define SYNODIC_MONTH 29.5305889f
#define NEW_MOON_JD 2451550.1f

static inline float deg_to_rad(float deg) { return deg * (float)M_PI / 180.0f; }

static inline float rad_to_deg(float rad) { return rad * 180.0f / (float)M_PI; }

static float normalize_deg(float deg)
{
    float out = fmodf(deg, 360.0f);
    if (out < 0.0f) {
        out += 360.0f;
    }
    return out;
}

static float normalize_hours(float hours)
{
    float out = fmodf(hours, 24.0f);
    if (out < 0.0f) {
        out += 24.0f;
    }
    return out;
}

static void moon_compute_ra_dec(float jd, float* ra_deg_out, float* dec_deg_out)
{
    float d = jd - 2451545.0f; // days since J2000.0

    float L = normalize_deg(218.316f + 13.176396f * d);
    float M = normalize_deg(134.963f + 13.064993f * d);
    float F = normalize_deg(93.272f + 13.229350f * d);

    float lambda = L + 6.289f * sinf(deg_to_rad(M));
    float beta = 5.128f * sinf(deg_to_rad(F));
    float eps = 23.439f - 0.0000004f * d;

    float lambda_rad = deg_to_rad(lambda);
    float beta_rad = deg_to_rad(beta);
    float eps_rad = deg_to_rad(eps);

    float sin_dec = sinf(beta_rad) * cosf(eps_rad) + cosf(beta_rad) * sinf(eps_rad) * sinf(lambda_rad);
    float dec_rad = asinf(sin_dec);
    float y = sinf(lambda_rad) * cosf(eps_rad) - tanf(beta_rad) * sinf(eps_rad);
    float x = cosf(lambda_rad);
    float ra_rad = atan2f(y, x);

    float ra_deg = normalize_deg(rad_to_deg(ra_rad));
    float dec_deg = rad_to_deg(dec_rad);

    if (ra_deg_out != NULL) {
        *ra_deg_out = ra_deg;
    }
    if (dec_deg_out != NULL) {
        *dec_deg_out = dec_deg;
    }
}

float moon_illumination(float jd)
{
    float age = fmodf(jd - NEW_MOON_JD, SYNODIC_MONTH);
    if (age < 0.0f) {
        age += SYNODIC_MONTH;
    }

    float phase = 2.0f * (float)M_PI * age / SYNODIC_MONTH;

    return 0.5f * (1.0f - cosf(phase));
}

float moon_phase_angle(float jd)
{
    float age = fmodf(jd - NEW_MOON_JD, SYNODIC_MONTH);
    if (age < 0.0f) {
        age += SYNODIC_MONTH;
    }

    return 360.0f * age / SYNODIC_MONTH;
}

int moon_calculate_rise_set(float latitude, float longitude, time_t utc_now, float target_tz_offset,
                            float local_tz_offset, const struct tm* tm_local, float* moonrise, float* moonset,
                            float* decl_out, float* illum_out)
{
    if (latitude < -90.0f || latitude > 90.0f) {
        ESP_LOGE(TAG, "Latitude must be between -90 and 90 degrees");
        return -EINVAL;
    }
    if (longitude < -180.0f || longitude > 180.0f) {
        ESP_LOGE(TAG, "Longitude must be between -180 and 180 degrees");
        return -EINVAL;
    }
    if (moonrise == NULL || moonset == NULL) {
        ESP_LOGE(TAG, "Output pointers must not be null");
        return -EINVAL;
    }

    (void)tm_local;

    time_t target_now = utc_now + (time_t)roundf(target_tz_offset * 3600.0f);
    time_t target_midnight = target_now - (target_now % 86400);
    time_t target_midnight_utc = target_midnight - (time_t)roundf(target_tz_offset * 3600.0f);

    float jd0 = astronomy_julian_date(target_midnight_utc);
    float jd_now = astronomy_julian_date(utc_now);

    float ra_deg = 0.0f;
    float dec_deg = 0.0f;
    moon_compute_ra_dec(jd0, &ra_deg, &dec_deg);

    if (decl_out != NULL) {
        *decl_out = dec_deg;
    }
    if (illum_out != NULL) {
        *illum_out = moon_illumination(jd_now);
    }

    float lat_rad = deg_to_rad(latitude);
    float dec_rad = deg_to_rad(dec_deg);
    float h0_rad = deg_to_rad(-0.3f); // approximate refraction + lunar radius

    float cos_h0 = (sinf(h0_rad) - sinf(lat_rad) * sinf(dec_rad)) / (cosf(lat_rad) * cosf(dec_rad));
    if (cos_h0 >= 1.0f) {
        ESP_LOGE(TAG, "Moon does not rise on this date at this location");
        return -ENODATA;
    }
    if (cos_h0 <= -1.0f) {
        ESP_LOGE(TAG, "Moon does not set on this date at this location");
        return -ENODATA;
    }

    float h0_deg = rad_to_deg(acosf(cos_h0));

    // GMST at reference epoch (target midnight UTC)
    double T = (jd0 - 2451545.0) / 36525.0;
    double gmst0 = 100.46061837 + 36000.770053608 * T + 0.000387933 * T * T - (T * T * T) / 38710000.0;
    gmst0 = fmod(gmst0, 360.0);
    if (gmst0 < 0.0) {
        gmst0 += 360.0;
    }

    // Approximate transit time (fraction of day, UT)
    float m0 = (ra_deg - longitude - (float)gmst0) / 360.0f;
    m0 = m0 - floorf(m0);

    // Initial rise/set estimates (fraction of day)
    float m_rise = m0 - h0_deg / 360.0f;
    float m_set = m0 + h0_deg / 360.0f;
    m_rise = m_rise - floorf(m_rise);
    m_set = m_set - floorf(m_set);

    // Iterative refinement: recompute moon position at estimated times
    // (Meeus, Astronomical Algorithms, Ch 15 — adapted for lunar motion)
    const float target_alt = -0.3f;
    for (int iter = 0; iter < 2; iter++) {
        // Refine moonrise
        {
            float ra_r, dec_r;
            moon_compute_ra_dec(jd0 + m_rise, &ra_r, &dec_r);
            float dec_r_rad = deg_to_rad(dec_r);
            float theta = normalize_deg((float)gmst0 + 360.985647f * m_rise);
            float H = normalize_deg(theta + longitude - ra_r);
            if (H > 180.0f) {
                H -= 360.0f;
            }
            float H_rad = deg_to_rad(H);
            float sin_alt = sinf(lat_rad) * sinf(dec_r_rad) + cosf(lat_rad) * cosf(dec_r_rad) * cosf(H_rad);
            float alt = rad_to_deg(asinf(sin_alt));
            float denom = 360.0f * cosf(dec_r_rad) * cosf(lat_rad) * sinf(H_rad);
            if (fabsf(denom) > 1e-6f) {
                m_rise += (alt - target_alt) / denom;
                m_rise = m_rise - floorf(m_rise);
            }
        }
        // Refine moonset
        {
            float ra_s, dec_s;
            moon_compute_ra_dec(jd0 + m_set, &ra_s, &dec_s);
            float dec_s_rad = deg_to_rad(dec_s);
            float theta = normalize_deg((float)gmst0 + 360.985647f * m_set);
            float H = normalize_deg(theta + longitude - ra_s);
            if (H > 180.0f) {
                H -= 360.0f;
            }
            float H_rad = deg_to_rad(H);
            float sin_alt = sinf(lat_rad) * sinf(dec_s_rad) + cosf(lat_rad) * cosf(dec_s_rad) * cosf(H_rad);
            float alt = rad_to_deg(asinf(sin_alt));
            float denom = 360.0f * cosf(dec_s_rad) * cosf(lat_rad) * sinf(H_rad);
            if (fabsf(denom) > 1e-6f) {
                m_set += (alt - target_alt) / denom;
                m_set = m_set - floorf(m_set);
            }
        }
    }

    // Convert from fraction of day (UT) to local hours
    float ut_rise = m_rise * 24.0f;
    float ut_set = m_set * 24.0f;

    *moonrise = normalize_hours(ut_rise + local_tz_offset);
    *moonset = normalize_hours(ut_set + local_tz_offset);

    return 0;
}

int moon_generate_instants(float moonrise, float moonset, float illumination, struct moon_instant* instants)
{
    if (instants == NULL) {
        return -EINVAL;
    }
    if (moonrise < 0.0f || moonrise >= 24.0f || moonset < 0.0f || moonset >= 24.0f) {
        return -EINVAL;
    }

    float illum = illumination;
    if (illum < 0.0f) {
        illum = 0.0f;
    }
    if (illum > 1.0f) {
        illum = 1.0f;
    }

    float span_end = moonset;
    if (moonset <= moonrise) {
        span_end += 24.0f;
    }
    float duration = span_end - moonrise;

    float t0 = moonrise;
    float t1 = moonrise + duration * 0.20f;
    float t2 = moonrise + duration * 0.35f;
    float t3 = moonrise + duration * 0.65f;
    float t4 = moonrise + duration * 0.80f;
    float t5 = span_end;

    instants[0].time = t0;
    instants[0].brightness = 0.0f;

    instants[1].time = t1;
    instants[1].brightness = 0.5f * illum;

    instants[2].time = t2;
    instants[2].brightness = illum;

    instants[3].time = t3;
    instants[3].brightness = illum;

    instants[4].time = t4;
    instants[4].brightness = 0.5f * illum;

    instants[5].time = t5;
    instants[5].brightness = 0.0f;

    return 0;
}
