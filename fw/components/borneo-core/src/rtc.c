#include <time.h>
#include <sys/time.h>
#include <string.h>
#include <errno.h>

#include <esp_system.h>
#include <esp_wifi.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_log.h>
#include <nvs_flash.h>

#include <drvfx/drvfx.h>

#include "borneo/utils/time.h"
#include "borneo/common.h"
#include "borneo/system.h"
#include "borneo/nvs.h"
#include "borneo/rtc.h"

#define TAG "rtc"
#define TIMEZONE_DEFAULT "CST-8"
#define NVS_RTC_NAMESPACE "rtc"
#define NVS_RTC_TZ_KEY "tz"
#define MAX_TZ_LEN 32

static StaticSemaphore_t s_lock_buf;
static SemaphoreHandle_t s_lock;

int bo_rtc_init()
{
    ESP_LOGI(TAG, "Initializing RTC...");

    s_lock = xSemaphoreCreateMutexStatic(&s_lock_buf);

    size_t tz_len = MAX_TZ_LEN;
    char tz[MAX_TZ_LEN];
    memset(tz, 0, MAX_TZ_LEN);

    nvs_handle_t nvs_handle;
    BO_TRY(bo_nvs_user_open(NVS_RTC_NAMESPACE, NVS_READWRITE, &nvs_handle));
    BO_NVS_AUTO_CLOSE(nvs_handle);
    int rc = nvs_get_str(nvs_handle, NVS_RTC_TZ_KEY, tz, &tz_len);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        strncpy(tz, TIMEZONE_DEFAULT, MAX_TZ_LEN);
        rc = 0;
        ESP_LOGI(TAG, "Time zone setting not found, using default time zone: %s", tz);
    }
    if (rc) {
        return rc;
    }

    BO_TRY(bo_tz_set(tz));

    return 0;
}

uint32_t bo_rtc_get_timestamp()
{
    if (xSemaphoreTake(s_lock, portMAX_DELAY) == pdTRUE) {
        BO_SEM_AUTO_RELEASE(s_lock);
        struct timeval tv;
        gettimeofday(&tv, NULL);
        return tv.tv_sec;
    }
    else {
        return -EBUSY;
    }
}

const char* bo_rtc_get_tz()
{
    //
    const char* tz = NULL;
    if (xSemaphoreTake(s_lock, portMAX_DELAY) == pdTRUE) {
        BO_SEM_AUTO_RELEASE(s_lock);
        tz = getenv("TZ");
    }
    return tz;
}

int bo_rtc_set_tz(const char* tz)
{
    if (tz == NULL) {
        return -EINVAL;
    }
    size_t tz_len = strnlen(tz, MAX_TZ_LEN);
    if (tz_len >= MAX_TZ_LEN) {
        return -EINVAL;
    }

    if (xSemaphoreTake(s_lock, portMAX_DELAY) == pdTRUE) {
        BO_SEM_AUTO_RELEASE(s_lock);

        BO_TRY(bo_tz_set(tz));

        // Saving the time-zone into the NVS
        nvs_handle_t nvs_handle;
        BO_TRY(bo_nvs_user_open(NVS_RTC_NAMESPACE, NVS_READWRITE, &nvs_handle));
        BO_NVS_AUTO_CLOSE(nvs_handle);

        BO_TRY(nvs_set_str(nvs_handle, NVS_RTC_TZ_KEY, tz));

        // TODO Post message
    }

    return 0;
}
