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
#include <borneo/ntc.h>
#include <borneo/power.h>
#include <borneo/nvs.h>

#include "fan.h"
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
    int overheated_count;
    int current_temp;
    int temp_window[TEMP_WINDOW_SIZE];
    uint8_t temp_window_index;
};

static int load_factory_settings();
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

#define THERMAL_NVS_FACTORY_NS "thermal"
#define THERMAL_NVS_KEY_KP "kp"
#define THERMAL_NVS_KEY_KI "ki"
#define THERMAL_NVS_KEY_KD "kd"
#define THERMAL_NVS_KEY_KEEP_TEMP "ktemp"
#define THERMAL_NVS_KEY_OVERHEATED_TEMP "ohtemp"
#define THERMAL_NVS_KEY_FAN_MODE "fmode"
#define THERMAL_NVS_KEY_FAN_MANUAL_POWER "fanmanpwr"

#define PID_Q 100
#define PID_PERIOD (1000)
#define PID_INTEGRAL_RESET_THRESHOLD 3
#define PID_INTEGRAL_MAX 50000
#define PID_INTEGRAL_MIN -50000
#define OVERHEATED_TEMP_COUNT_MAX 3

#define FAN_POWER_MIN 10

#define OUTPUT_MIN 10
#define OUTPUT_MAX 100

const struct thermal_settings THERMAL_DEFAULT_SETTINGS = {
    .kp = 250,
    .ki = 10,
    .kd = 50,
    .keep_temp = 45,
    .overheated_temp = 65,
    .fan_mode = THERMAL_FAN_MODE_PID,
    .fan_manual_power = 75,
};

static struct thermal_settings _settings;
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
        }
    }

    if (_settings.fan_mode != THERMAL_FAN_MODE_DISABLED) {
        fan_set_power(0);
    }

    BO_TRY(thermal_reinit());

    if (THERMAL_FAN_MODE_PID == _settings.fan_mode) {
        const esp_timer_create_args_t timer_args = {
            .callback = &thermal_timer_callback,
            .name = "thermal_timer",
        };
        BO_TRY(esp_timer_create(&timer_args, &_thermal.timer));
        BO_TRY(esp_timer_start_periodic(_thermal.timer, (uint64_t)PID_PERIOD * 1000));
    }
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

    rc = nvs_get_u8(handle, THERMAL_NVS_KEY_OVERHEATED_TEMP, &_settings.overheated_temp);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.overheated_temp = THERMAL_DEFAULT_SETTINGS.overheated_temp;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_get_u8(handle, THERMAL_NVS_KEY_FAN_MODE, &_settings.fan_mode);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.fan_mode = THERMAL_DEFAULT_SETTINGS.fan_mode;
        rc = 0;
    }
    if (rc) {
        goto _EXIT_CLOSE;
    }

    rc = nvs_get_u8(handle, THERMAL_NVS_KEY_FAN_MANUAL_POWER, &_settings.fan_manual_power);
    if (rc == ESP_ERR_NVS_NOT_FOUND) {
        _settings.fan_manual_power = THERMAL_DEFAULT_SETTINGS.fan_manual_power;
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

uint8_t thermal_pid_step(int32_t current_temp)
{
    struct pid* pid = &_thermal.pid;

    int32_t error = current_temp - _settings.keep_temp;

    if (abs(error) <= 1) { // ±1°C
        return (uint8_t)(pid->last_output);
    }

    int32_t p_term = _settings.kp * error;

    if (abs(error) >= 2) {
        int32_t new_integral = pid->integral + _settings.ki * error;
        if (new_integral > PID_INTEGRAL_MAX) {
            pid->integral = PID_INTEGRAL_MAX;
        }
        else if (new_integral < PID_INTEGRAL_MIN) {
            pid->integral = PID_INTEGRAL_MIN;
        }
        else {
            pid->integral = new_integral;
        }
    }

    int32_t d_term = _settings.kd * (error - pid->prev_error);

    int32_t output = p_term + pid->integral + d_term;

    pid->prev_error = error;

    if (output > OUTPUT_MAX * PID_Q) {
        output = OUTPUT_MAX;
        if (error > 0) {
            pid->integral -= _settings.ki * error;
        }
    }
    else if (output < OUTPUT_MIN * PID_Q) {
        output = 0;
        if (error < 0) {
            pid->integral -= _settings.ki * error;
        }
    }
    else {
        output /= PID_Q;
    }

    pid->last_output = output;
    return (uint8_t)output;
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

    // Continuous detection of high temperatures multiple times will trigger an emergency shutdown of the lights.
    if (bo_power_is_on() && _thermal.current_temp >= _settings.overheated_temp) {
        _thermal.overheated_count++;
        ESP_LOGW(TAG, "[%u/%u] Too hot!", _thermal.overheated_count, OVERHEATED_TEMP_COUNT_MAX);
        if (_thermal.overheated_count > OVERHEATED_TEMP_COUNT_MAX && bo_power_is_on()) {
            fan_set_power(OUTPUT_MAX);
            ESP_LOGW(TAG, "Over temperature(temp=%d, set=%u)! shuting down...", _thermal.current_temp,
                     _settings.overheated_temp);
            bo_power_shutdown(BO_SHUTDOWN_REASON_OVERHEATED);
            _thermal.overheated_count = 0;
            return;
        }
    }
    else {
        _thermal.overheated_count = 0;
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
    if (keep_temp < 35 || keep_temp >= _settings.overheated_temp) {
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