#pragma once

#include <stdint.h>
#include <sys/time.h>
#include <sdkconfig.h>

#ifdef __cplusplus
extern "C" {
#endif
/* Declarations of this file */


typedef enum {
    PUMP_STATE_IDLE = 0, /// Idle state
    PUMP_STATE_WAIT = 1, /// Waiting for a job
    PUMP_STATE_BUSY = 2, /// Busy
    PUMP_STATE_INVALID, /// Invalid state
} pump_state_t;

typedef struct {
    uint32_t speed; ///< Liquid flow speed, unit: microliters per second (μL/sec), `0` means not calibrated.
    time_t last_calibration_time;
} pump_channel_settings_t;

typedef struct {
    pump_channel_settings_t channels[CONFIG_PUMP_CHANNEL_COUNT];
} pump_device_settings_t;

typedef struct {
    uint32_t speed;
    pump_state_t state;
} pump_channel_status_t;

int pump_init();
int pump_volume(size_t ch, uint32_t vol);
int pump_duration(size_t ch, int64_t duration);
int pump_volume_all(const uint32_t* vols);
int pump_on(size_t ch);
int pump_off(size_t ch);
int pump_update_speed(size_t ch, uint32_t speed);
bool pump_is_any_busy();
int pump_get_channel_info(size_t ch, pump_channel_status_t* status_out);

#ifdef __cplusplus
}
#endif
