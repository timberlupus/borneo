#include <time.h>
#include <sys/time.h>

#include <esp_system.h>
#include <esp_wifi.h>
#include <esp_event.h>
#include <esp_log.h>

#include <borneo/common.h>
#include <borneo/rtc.h>

uint32_t bo_rtc_get_timestamp()
{
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return tv.tv_sec;
}

const char* bo_rtc_get_tz() { return getenv("TZ"); }

void bo_rtc_set_tz(const char* tz)
{
    setenv("TZ", tz, 1);
    tzset();
}
