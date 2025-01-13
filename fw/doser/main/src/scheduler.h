#pragma once

#include <stdint.h>
#include <stdbool.h>
#include <sys/time.h>

#include <borneo/cron.h>

#ifdef __cplusplus
extern "C" {
#endif
/* Declarations of this file */

#define SCHEDULER_MAX_JOB_NAME 128
#define SCHEDULER_MAX_JOBS 10

struct scheduled_job {
    bool can_parallel;
    struct cron when;
    uint32_t payloads[CONFIG_PUMP_CHANNEL_COUNT];
    time_t last_execute_time;
};

struct schedule {
    uint8_t jobs_count;
    struct scheduled_job jobs[SCHEDULER_MAX_JOBS];
};

struct scheduler_status {
    bool is_running;
    struct schedule schedule;
};

int scheduler_init();

int scheduler_start();

const struct schedule* scheduler_get_schedule();

int scheduler_update_schedule(const struct schedule* schedule);

#ifdef __cplusplus
}
#endif
