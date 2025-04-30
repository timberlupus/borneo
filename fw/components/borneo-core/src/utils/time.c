// https://stackoverflow.com/questions/7960318/math-to-convert-seconds-since-1970-into-date-and-vice-versa

#include <time.h>
#include <sys/time.h>
#include <errno.h>

#include <freertos/FreeRTOS.h>

#include "borneo/common.h"
#include "borneo/utils/time.h"

const static int MDAYS[] = { 0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334 };

int64_t to_unix_time(int year, int month, int day, int hour, int min, int sec)
{
    // Cumulative days for each previous month of the year
    // Year is to be relative to the epoch start
    year -= 1970;
    // Compensation of the non-leap years
    int minusYear = 0;
    // Detect potential lead day (February 29th) in this year?
    if (month >= 3) {
        // Then add this year into "sum of leap days" computation
        year++;
        // Compute one year less in the non-leap years sum
        minusYear = 1;
    }

    return
        // + Seconds from computed minutes
        60
        * (
            // + Minutes from computed hours
            60
                * (
                    // + Hours from computed days
                    24
                        * (
                            // + Day (zero index)
                            day
                            - 1
                            // + days in previous months (leap day not
                            // included)
                            + MDAYS[month - 1]
                            // + days for each year divisible by 4
                            // (starting from 1973)
                            + ((year + 1) / 4)
                            // - days for each year divisible by 100
                            // (starting from 2001)
                            - ((year + 69) / 100)
                            // + days for each year divisible by 400
                            // (starting from 2001)
                            + ((year + 369) / 100 / 4)
                            // + days for each year (as all are non-leap
                            // years) from 1970 (minus this year if
                            // potential leap day taken into account)
                            + (5 * 73 /*=365*/) * (year - minusYear)
                            // + Hours
                            )
                    + hour
                    // + Minutes
                    )
            + min
            // + Seconds
            )
        + sec;
}

int bo_tz_set(const char* tz)
{
    if (tz == NULL) {
        return -EINVAL;
    }

    static StaticSemaphore_t mutex_buffer;
    static SemaphoreHandle_t tz_mutex = NULL;

    if (tz_mutex == NULL) {
        tz_mutex = xSemaphoreCreateMutexStatic(&mutex_buffer);
        if (tz_mutex == NULL) {
            ESP_LOGE(TAG, "Failed to create mutex for timezone");
            return -ENODATA;
        }
    }

    if (xSemaphoreTake(tz_mutex, pdMS_TO_TICKS(100)) != pdTRUE) {
        ESP_LOGE(TAG, "Timeout acquiring timezone mutex");
        return -EINVAL;
    }

    setenv("TZ", tz, 1);
    tzset();

    xSemaphoreGive(tz_mutex);

    return ESP_OK;
}
