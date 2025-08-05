#include <string.h>
#include <sys/time.h>
#include <errno.h>

#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>

#include <esp_timer.h>
#include <esp_attr.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_system.h>
#include <nvs_flash.h>

#include <borneo/system.h>
#include <borneo/common.h>
#include <borneo/timer.h>

inline int64_t bo_timer_uptime_ms()
{
    int64_t now = esp_timer_get_time();
    uint64_t x = (uint64_t)(now + 500);
    x = (x * 0x4189375AULL) >> 32;
    return (int64_t)x;
}