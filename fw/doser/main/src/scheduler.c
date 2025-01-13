#include "sdkconfig.h"

#include <memory.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <sys/time.h>

#include <esp_event.h>
#include <esp_log.h>
#include <esp_smartconfig.h>
#include <esp_system.h>
#include <freertos/FreeRTOS.h>
#include <freertos/FreeRTOSConfig.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>
#include <nvs_flash.h>

#include <borneo/utils/bit-utils.h>
#include <borneo/utils/time.h>

#include <borneo/common.h>
#include <borneo/system.h>
#include <borneo/cron.h>
#include <borneo/rtc.h>
#include "pump.h"
#include "scheduler.h"

static void scheduler_task(void* params);
static int load_settings();
static int restore_default_config();
static int save_settings();

static const char* TAG = "SCHEDULER";
static const char* NVS_NAMESPACE = "scheduler";
static const char* NVS_SCHEDULER_CONFIG_KEY = "config";

struct scheduler_status s_scheduler_status;

int scheduler_init()
{
    // TODO FIXME
    int error = load_settings();
    if (error == ESP_ERR_NVS_NOT_FOUND || error == ESP_ERR_NVS_INVALID_LENGTH) {
        BO_MUST(restore_default_config());
    }
    else if (error != 0) {
        ESP_LOGE(TAG, "Failed to load Scheduler data from NVS. Error code=%X", error);
        return -1;
    }
    return 0;
}

int scheduler_start()
{
    xTaskCreate(&scheduler_task, "scheduler_task", 1024 * 8, NULL, tskIDLE_PRIORITY + 4, NULL);
    return 0;
}

const struct schedule* scheduler_get_schedule() { return &s_scheduler_status.schedule; }

int scheduler_update_schedule(const struct schedule* schedule)
{
    struct schedule* sch = &s_scheduler_status.schedule;
    for (size_t i = 0; i < schedule->jobs_count; i++) {
        const struct scheduled_job* src_job = &schedule->jobs[i];
        struct scheduled_job* dest_job = &sch->jobs[i];

        dest_job->can_parallel = src_job->can_parallel;
        memcpy(&dest_job->when, &src_job->when, sizeof(struct cron));
        memcpy(&dest_job->payloads, &src_job->payloads, sizeof(uint32_t) * CONFIG_PUMP_CHANNEL_COUNT);
    }
    s_scheduler_status.schedule.jobs_count = schedule->jobs_count;

    return save_settings();
}

static void scheduler_task(void* params)
{
    // 500 ms
    const TickType_t freq = 500 / portTICK_PERIOD_MS;
    TickType_t last_wake_time = xTaskGetTickCount();

    struct schedule* sch = &s_scheduler_status.schedule;
    for (;;) {
        // TODO use DS1304
        time_t current_time;
        time(&current_time);
        struct tm* const rtc_now = localtime(&current_time);

        time_t rtc_time = mktime(rtc_now);
        for (size_t i = 0; i < sch->jobs_count; i++) {
            struct scheduled_job* job = &sch->jobs[i];
            if (cron_is_valid(&job->when, rtc_now)) {
                int64_t since_last = rtc_time - job->last_execute_time;
                // TODO FIXME
                if (since_last > 60LL) {
                    ESP_LOGI(TAG, "A scheduled job started...");
                    job->last_execute_time = rtc_time;
                    // Execute the job
                    if (pump_volume_all(job->payloads) != 0) {
                        ESP_LOGE(TAG, "Failed to start pump!");
                    }
                }
            }
        }

        vTaskDelayUntil(&last_wake_time, freq);
    }
    vTaskDelete(NULL);
}

static int save_settings()
{
    ESP_LOGI(TAG, "Saving config...");

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) {
        return err;
    }

    err = nvs_set_blob(nvs_handle, NVS_SCHEDULER_CONFIG_KEY, &s_scheduler_status, sizeof(s_scheduler_status));

    if (err != ESP_OK) {
        return err;
    }

    err = nvs_commit(nvs_handle);
    if (err != ESP_OK) {
        return err;
    }

    nvs_close(nvs_handle);
    return ESP_OK;
}

static int load_settings()
{
    ESP_LOGI(TAG, "Loading config...");

    nvs_handle_t nvs_handle;
    esp_err_t err = nvs_open(NVS_NAMESPACE, NVS_READWRITE, &nvs_handle);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to open NVS, error=%X", err);
        return err;
    }

    size_t size = sizeof(s_scheduler_status);
    err = nvs_get_blob(nvs_handle, NVS_SCHEDULER_CONFIG_KEY, &s_scheduler_status, &size);
    if (err != ESP_OK) {
        ESP_LOGE(TAG, "Failed to get blob from NVS, error=%X", err);
        return err;
    }

    nvs_close(nvs_handle);
    return ESP_OK;
}

static int restore_default_config()
{
    ESP_LOGI(TAG, "Restoring default config...");
    memset(&s_scheduler_status, 0, sizeof(s_scheduler_status));
    s_scheduler_status.is_running = false;
    return save_settings();
}