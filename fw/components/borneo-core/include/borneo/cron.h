#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Posix-like CRON item
 */
struct cron {
    uint16_t months; ///< Months
    uint32_t dom; ///< Days of a month
    uint8_t dow; ///< Days of a week, 0~6
    uint32_t hours; ///< Hours of a day, 0~23
    uint64_t minutes; ///< Minutes of an hour, 0~59
};

void cron_init(struct cron* self);

bool cron_is_valid(const struct cron* self, const struct tm* rtc);

#ifdef __cplusplus
}
#endif