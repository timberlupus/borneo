#include <string.h>
#include <errno.h>
#include <stdint.h>
#include <stdbool.h>

#include <esp_system.h>
#include <esp_event.h>
#include <esp_timer.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <esp_err.h>
#include <esp_log.h>
#include <nvs_flash.h>

#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>

#include "ntc.h"
#include "fan.h"
#include "protect.h"
#include "thermal.h"

#define TEMP_WINDOW_SIZE 8

struct pid {
    int32_t prev_error;
    int32_t integral;
    int32_t last_output;
};

struct thermal_state {
    esp_timer_handle_t timer;
    struct pid pid;
    int current_temp;
    int temp_window[TEMP_WINDOW_SIZE];
    uint8_t temp_window_index;
};

static int load_factory_settings();
static int load_user_settings();
static void thermal_timer_callback(void* args);
static int thermal_reinit();
static uint8_t thermal_pid_step(int32_t current_temp);
static int update_temp_average(int new_sample);

#define CLAMP(x, _min, _max)                                                                                           \
    if ((x) > (_max))                                                                                                  \
        (x) = (_max);                                                                                                  \
    if ((x) < (_min))                                                                                                  \
        (x) = (_min);

#define TAG "thermal"

#define THERMAL_NVS_USER_NS "thermal"
#define THERMAL_NVS_FACTORY_NS "thermal"
#define THERMAL_NVS_KEY_KP "kp"
#define THERMAL_NVS_KEY_KI "ki"
#define THERMAL_NVS_KEY_KD "kd"
#define THERMAL_NVS_KEY_KEEP_TEMP "ktemp"
#define THERMAL_NVS_KEY_FAN_MODE "fmode"
#define THERMAL_NVS_KEY_FAN_MANUAL_POWER "fanmanpwr"

#define PID_Q 100
#define PID_PERIOD (1000)
#define PID_INTEGRAL_RESET_THRESHOLD 3
#define PID_INTEGRAL_MAX 50000
#define PID_INTEGRAL_MIN -50000

#define OUTPUT_MIN 10
#define OUTPUT_MAX 100

#define KEEP_TEMP_MIN 35

const struct thermal_settings THERMAL_DEFAULT_SETTINGS = {
    .kp = 250,
    .ki = 10,
    .kd = 50,
    .keep_temp = 45,
    .fan_mode = THERMAL_FAN_MODE_PID,
    .fan_manual_power = 75,
};

static struct thermal_settings _settings = { 0 };
static struct thermal_state _thermal = { 0 };

static int thermal_reinit()
{
    if (THERMAL_FAN_MODE_PID == _settings.fan_mode) {
        _thermal.pid.integral = 0;
        _thermal.pid.prev_error = 0;
        _thermal.pid.last_output = 0;
        thermal_timer_callback(NULL);
    }
    return 0;
}

int thermal_init()
{
    ESP_LOGI(TAG, "Initializing thermal management subsystem...");

    BO_TRY(load_factory_settings());
    BO_TRY(load_user_settings());

    if (ntc_init() != 0) {
        if (_settings.fan_mode != THERMAL_FAN_MODE_DISABLED) {
            fan_set_power(OUTPUT_MAX);
        }
        return -1;
    }

    {
        // Fill the window
        for (size_t ti = 0; ti < TEMP_WINDOW_SIZE; ti++) {
            int rc = ntc_read_temp(_thermal.temp_window + ti);
            if (rc == 0) {
                _thermal.current_temp = _thermal.temp_window[ti];
            }
            else {
                _thermal.temp_window[ti] = -1;
            }
            vTaskDelay(pdMS_TO_TICKS(10));
        }
    }

    if (_settings.fan_mode != THERMAL_FAN_MODE_DISABLED) {
        fan_set_power(0);
    }

    if (THERMAL_FAN_MODE_PID == _settings.fan_mode) {
        const esp_timer_create_args_t timer_args = {
            .callback = &thermal_timer_callback,
            .name = "thermal_timer",
        };
        BO_TRY_ESP(esp_timer_create(&timer_args, &_thermal.timer));
        BO_TRY_ESP(esp_timer_start_periodic(_thermal.timer, (uint64_t)PID_PERIOD * 1000));
    }

    BO_TRY(thermal_reinit());

    ESP_LOGI(TAG, "Thermal management module has been initialized successfully.");

    return 0;
}

int thermal_get_current_temp() { return _thermal.current_temp; }

int load_factory_settings()
{
    int rc;
    nvs_handle_t handle;
    rc = bo_nvs_factory_open(THERMAL_NVS_FACTORY_NS, NVS_READWRITE, &handle);
    if (rc) {
        goto _EXIT_WITHOUT_CLOSE;
    }

    rc = nvs_get_i32(handle, THERMAL_NVS_KEY_KP, &_settings.kp);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.kp = THERMAL_DEFAULT_SETTINGS.kp;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_get_i32(handle, THERMAL_NVS_KEY_KI, &_settings.ki);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.ki = THERMAL_DEFAULT_SETTINGS.ki;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_get_i32(handle, THERMAL_NVS_KEY_KD, &_settings.kd);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.kd = THERMAL_DEFAULT_SETTINGS.kd;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_get_u8(handle, THERMAL_NVS_KEY_KEEP_TEMP, &_settings.keep_temp);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.keep_temp = THERMAL_DEFAULT_SETTINGS.keep_temp;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

_EXIT_CLOSE:
    bo_nvs_close(handle);
_EXIT_WITHOUT_CLOSE:
    return rc;
}

int load_user_settings()
{
    nvs_handle_t handle;
    BO_TRY(bo_nvs_user_open(THERMAL_NVS_USER_NS, NVS_READWRITE, &handle));
    BO_NVS_AUTO_CLOSE(handle);

    int rc = nvs_get_u8(handle, THERMAL_NVS_KEY_FAN_MODE, &_settings.fan_mode);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.fan_mode = THERMAL_DEFAULT_SETTINGS.fan_mode;
        rc = 0;
    }
    if (rc) {
        return rc;
    }

    rc = nvs_get_u8(handle, THERMAL_NVS_KEY_FAN_MANUAL_POWER, &_settings.fan_manual_power);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.fan_manual_power = THERMAL_DEFAULT_SETTINGS.fan_manual_power;
        rc = 0;
    }
    if (rc) {
        return rc;
    }

    return rc;
}

uint8_t thermal_pid_step(int32_t current_temp)
{
    struct pid* pid = &_thermal.pid;

    int32_t error = current_temp - _settings.keep_temp;

    // Dead zone: Keep the last output within ±1°C and gently release the integral to avoid long-term historical error
    // residue
    if (abs(error) <= 1) {
        pid->integral -= pid->integral / 8;
        return (uint8_t)(pid->last_output);
    }

    // Period normalization: Make PID_PERIOD changes not affect the feel (based on seconds)
    const int32_t dt_ms = PID_PERIOD;
    const int32_t ki_eff = (int32_t)((int64_t)_settings.ki * dt_ms / 1000); // Ki * dt
    const int32_t kd_eff = (int32_t)((int64_t)_settings.kd * 1000 / dt_ms); // Kd / dt

    // Calculate each term (still in PID_Q amplified domain)
    int32_t p_term = _settings.kp * error;
    int32_t d_term = kd_eff * (error - pid->prev_error);

    // Estimate unsaturated output
    int32_t out_unsat = p_term + pid->integral + d_term;

    // Saturation boundaries (Q domain)
    const int32_t hi_q = OUTPUT_MAX * PID_Q;
    const int32_t lo_q = OUTPUT_MIN * PID_Q;
    // Below this threshold, the fan is considered off

    bool sat_hi = out_unsat > hi_q;
    bool sat_lo = out_unsat < lo_q;

    // Conditional integration:
    // - Can integrate if not saturated
    // - If already high saturated, allow integration only when error decreases (error < 0) to help "desaturate"
    // - If already low saturated, allow integration only when error increases (error > 0)
    bool allow_i = true;
    if (sat_hi && error > 0)
        allow_i = false;
    if (sat_lo && error < 0)
        allow_i = false;

    if (abs(error) >= 2 && allow_i) {
        int64_t new_i = (int64_t)pid->integral + (int64_t)ki_eff * error;
        if (new_i > PID_INTEGRAL_MAX)
            new_i = PID_INTEGRAL_MAX;
        if (new_i < PID_INTEGRAL_MIN)
            new_i = PID_INTEGRAL_MIN;
        pid->integral = (int32_t)new_i;
    }

    pid->prev_error = error;

    // Recalculate and quantize to 0..100
    int32_t out_q = p_term + pid->integral + d_term;
    uint8_t out;
    if (out_q <= lo_q) {
        out = 0;
        // Turn off if below the starting threshold
    }
    else if (out_q >= hi_q) {
        out = OUTPUT_MAX;
    }
    else {
        out = (uint8_t)(out_q / PID_Q);
    }

    // Output slew rate limit: restrict the maximum change per cycle to improve user experience and suppress
    // noise-induced jumps
    const int32_t max_step = 10;
    // Maximum change of 10% per second
    int32_t delta = (int32_t)out - pid->last_output;
    if (delta > max_step)
        delta = max_step;
    if (delta < -max_step)
        delta = -max_step;
    out = (uint8_t)(pid->last_output + delta);

    pid->last_output = out;
    return out;
}

static void thermal_timer_callback(void* args)
{
    int new_temp = -1;
    int rc = ntc_read_temp(&new_temp);
    if (rc != 0) {
        ESP_LOGE(TAG, "Temperature sensor fault or not connected.");
        if (bo_power_is_on()) {
            fan_set_power(OUTPUT_MAX);
        }
        else {
            fan_set_power(0);
        }
        return;
    }
    update_temp_average(new_temp);

    uint8_t fan_power_to_set = OUTPUT_MAX;

    // If the device has been shut down and the temperature is suitable, turn off the fan.
    if (_thermal.current_temp <= _settings.keep_temp && !bo_power_is_on()) {
        if (fan_get_power() > 0) {
            fan_set_power(0);
            // pid_clear(&_pid);
            // Respond to shutdown event to clear PID.
        }
        return;
    }

    // Below the emergency shutdown temperature, execute PID fan speed control.
    fan_power_to_set = thermal_pid_step(_thermal.current_temp);

    if (fan_power_to_set != fan_get_power()) {
        fan_set_power(fan_power_to_set);
        ESP_LOGI(TAG, "Changing fan power: temp=%d, keep_temp=%d, fan=%u%%\t", _thermal.current_temp,
                 _settings.keep_temp, fan_power_to_set);
    }
}

const struct thermal_settings* thermal_get_settings() { return &_settings; }

int thermal_set_pid(int32_t kp, int32_t ki, int32_t kd)
{
    _settings.kp = kp;
    _settings.ki = ki;
    _settings.kd = kd;

    BO_TRY(thermal_reinit());
    return 0;
}

int thermal_set_keep_temp(uint8_t keep_temp)
{
    if (keep_temp < KEEP_TEMP_MIN || keep_temp >= bo_protect_get_overheated_temp()) {
        return -EINVAL;
    }

    _settings.keep_temp = keep_temp;

    return 0;
}

int update_temp_average(int new_sample)
{
    _thermal.temp_window[_thermal.temp_window_index % TEMP_WINDOW_SIZE] = new_sample;
    _thermal.temp_window_index++;

    int sum = 0;
    int n = 0;
    for (size_t i = 0; i < TEMP_WINDOW_SIZE; i++) {
        if (_thermal.temp_window[i] >= 0) {
            sum += _thermal.temp_window[i];
            n++;
        }
    }
    if (n == 0) {
        return -1;
    }
    _thermal.current_temp = (int)((sum + (n / 2)) / n);
    return 0;
}