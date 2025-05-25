#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <esp_system.h>
#include <esp_err.h>
#include <esp_log.h>
#include <driver/ledc.h>
#include <nvs_flash.h>
#include <driver/gpio.h>

#if SOC_DAC_SUPPORTED
#include <driver/dac.h>
#endif

#include <borneo/system.h>
#include <borneo/nvs.h>

#include "rmtpwm.h"
#include "fan.h"

#define NVS_FAN_NAMESPACE "fan"
#define FAN_NVS_KEY_DAC_ENABLED "dac_en"
#define FAN_NVS_KEY_PWM_ENABLED "pwm_en"

#define TAG "fan"

int fan_factory_settings_load();

static portMUX_TYPE _status_lock = portMUX_INITIALIZER_UNLOCKED;

static struct fan_status _status = { 0 };
static struct fan_factory_settings _factory_settings = { 0 };

int fan_init()
{
    ESP_LOGI(TAG, "Initializing fan driver...");

    BO_TRY(fan_factory_settings_load());

#if CONFIG_LYFI_FAN_CTRL_SHUTDOWN_ENABLED
    {
        uint64_t selected_gpios = 0ULL;
        selected_gpios |= 1ULL << CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO;

        gpio_config_t io_conf = { 0 };
        io_conf.intr_type = GPIO_INTR_DISABLE;
        io_conf.mode = GPIO_MODE_OUTPUT;
        io_conf.pin_bit_mask = selected_gpios;
        io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
        io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
        BO_TRY(gpio_config(&io_conf));

        BO_TRY(gpio_set_level(CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO, 0));
        ESP_LOGI(TAG, "Fan shutdown GPIO%u initialized.", CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO);
    }
#endif // CONFIG_LYFI_FAN_CTRL_SHUTDOWN_ENABLED

    bool dac_enabled = _factory_settings.flags & FAN_FLAG_DAC_ENABLED;
#if CONFIG_LYFI_FAN_CTRL_PWM_ENABLED
    bool pwm_enabled = _factory_settings.flags & FAN_FLAG_PWM_ENABLED;
#else
    bool pwm_enabled = false;
#endif // CONFIG_LYFI_FAN_CTRL_PWM_ENABLED

    if (dac_enabled || pwm_enabled) {
        BO_TRY(rmtpwm_init());
    }

    if (dac_enabled) {
#if SOC_DAC_SUPPORTED
        ESP_LOGI(TAG, "Fan driver using DAC, channel=%u", CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL);
        BO_TRY(dac_output_enable(CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL));
        BO_TRY(dac_output_voltage(CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL, LYFI_FAN_CTRL_DAC_DUTY_MAX));
#else
        BO_TRY(rmtpwm_dac_init());
        BO_TRY(rmtpwm_set_dac_duty(RMTPWM_DUTY_MAX));
#endif
    }

#if CONFIG_LYFI_FAN_CTRL_PWM_ENABLED
    if (pwm_enabled) {
        ESP_LOGI(TAG, "Fan PWM output enabled, GPIO=%i", CONFIG_LYFI_FAN_CTRL_PWM_GPIO);
        BO_TRY(rmtpwm_pwm_init());
        BO_TRY(rmtpwm_set_pwm_duty(0));
    }
#endif // CONFIG_LYFI_FAN_CTRL_PWM_ENABLED

    ESP_LOGI(TAG, "Fan driver initizlied.");
    return 0;
}

int fan_set_power(uint8_t value)
{
    if (value > FAN_POWER_MAX) {
        value = FAN_POWER_MAX;
    }

    portENTER_CRITICAL(&_status_lock);
    if (_status.power == value) {
        portEXIT_CRITICAL(&_status_lock);
        return 0;
    }
    else {
        _status.power = value;
        portEXIT_CRITICAL(&_status_lock);
    }

#if CONFIG_LYFI_FAN_CTRL_SHUTDOWN_ENABLED
    if (value == 0) {
        BO_TRY(gpio_set_level(CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO, 0));
    }
    else {
        BO_TRY(gpio_set_level(CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO, 1));
    }
#endif // LYFI_FAN_CTRL_SHUTDOWN_ENABLED

#if CONFIG_LYFI_FAN_CTRL_PWM_ENABLED
    if (_factory_settings.flags & FAN_FLAG_PWM_ENABLED) {
        BO_TRY(rmtpwm_set_pwm_duty(value));
        ESP_LOGI(TAG, "Set fan power, method: PWM, power=%u%%", value);
    }
#endif // CONFIG_LYFI_FAN_CTRL_PWM_ENABLED

    if (_factory_settings.flags & FAN_FLAG_DAC_ENABLED) {
#if SOC_DAC_SUPPORTED
        // Built-in DAC
        {
            const int DUTY_RANGE = CONFIG_LYFI_FAN_CTRL_DAC_DUTY_MAX - CONFIG_LYFI_FAN_CTRL_DAC_DUTY_MIN;
            int duty = (DUTY_RANGE * value + FAN_POWER_MAX / 2) / FAN_POWER_MAX;
            duty = CONFIG_LYFI_FAN_CTRL_DAC_DUTY_MAX - duty;

            if (duty <= CONFIG_LYFI_FAN_CTRL_DAC_DUTY_MIN) {
                duty = CONFIG_LYFI_FAN_CTRL_DAC_DUTY_MIN;
            }
            if (duty >= CONFIG_LYFI_FAN_CTRL_DAC_DUTY_MAX) {
                duty = 0xFF; // DAC_MAX_DUTY
            }
            BO_TRY(dac_output_voltage(CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL, dac_value));
            ESP_LOGI(TAG, "Set fan power, method: DAC, power=%u/100, DAC-value=%hhu", value, dac_value);
        }
#else
        // PWMDAC
        {
            const int DUTY_RANGE = CONFIG_LYFI_FAN_CTRL_PWMDAC_DUTY_MAX - CONFIG_LYFI_FAN_CTRL_PWMDAC_DUTY_MIN;
            int duty = (DUTY_RANGE * value + FAN_POWER_MAX / 2) / FAN_POWER_MAX;
            duty = CONFIG_LYFI_FAN_CTRL_PWMDAC_DUTY_MAX - duty;

            if (duty <= CONFIG_LYFI_FAN_CTRL_PWMDAC_DUTY_MIN) {
                duty = CONFIG_LYFI_FAN_CTRL_PWMDAC_DUTY_MIN;
            }
            if (duty >= CONFIG_LYFI_FAN_CTRL_PWMDAC_DUTY_MAX) {
                duty = RMTPWM_DUTY_MAX;
            }
            BO_TRY(rmtpwm_set_dac_duty((uint8_t)duty));
            ESP_LOGI(TAG, "Set fan power, method: PWM DAC, power=%d, PWM-DAC_duty=%d", value, duty);
        }
#endif // CONFIG_IDF_TARGET_ESP32C3
    }

    return 0;
}

uint8_t fan_get_power()
{
    uint8_t power;
    portENTER_CRITICAL(&_status_lock);
    power = _status.power;
    portEXIT_CRITICAL(&_status_lock);
    return power;
}

struct fan_status fan_get_status()
{
    struct fan_status status;
    portENTER_CRITICAL(&_status_lock);
    status = _status;
    portEXIT_CRITICAL(&_status_lock);
    return status;
}

int fan_factory_settings_load()
{
    nvs_handle_t nvs_handle;
    BO_TRY(bo_nvs_factory_open(NVS_FAN_NAMESPACE, NVS_READWRITE, &nvs_handle));

    {
        uint8_t en = 0;
        int rc = nvs_get_u8(nvs_handle, FAN_NVS_KEY_DAC_ENABLED, &en);
        if (rc == 0) {
            if (en) {
                _factory_settings.flags |= FAN_FLAG_DAC_ENABLED;
            }
            else {
                _factory_settings.flags &= ~FAN_FLAG_DAC_ENABLED;
            }
        }
        else {
            _factory_settings.flags |= FAN_FLAG_DAC_ENABLED;
        }
    }

#if CONFIG_LYFI_FAN_CTRL_PWM_ENABLED
    {
        uint8_t en = 0;
        int rc = nvs_get_u8(nvs_handle, FAN_NVS_KEY_PWM_ENABLED, &en);
        if (rc == 0) {
            if (en) {
                _factory_settings.flags |= FAN_FLAG_PWM_ENABLED;
            }
            else {
                _factory_settings.flags &= ~FAN_FLAG_PWM_ENABLED;
            }
        }
        else {
            _factory_settings.flags &= ~FAN_FLAG_PWM_ENABLED;
        }
    }
#endif // CONFIG_LYFI_FAN_CTRL_PWM_ENABLED

    bo_nvs_close(nvs_handle);

    return 0;
}