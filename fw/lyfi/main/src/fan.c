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
#define FAN_NVS_KEY_USE_PWM "use_pwm"

#define TAG "fan"

static struct fan_status _status = { 0 };
static struct fan_settings _settings = { 0 };

#define PWMDAC_FAN_MIN_DUTY 30 ///< About ~3.5V
#define PWMDAC_FAN_MAX_DUTY 80 ///< About ~12V

int fan_init()
{
    ESP_LOGI(TAG, "Initializing fan driver...");

#if CONFIG_LYFI_FAN_CTRL_SHUTDOWN_ENABLED
    {
        uint64_t selected_gpios = 0ULL;
        selected_gpios |= 1ULL << CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO;

        gpio_config_t io_conf;
        io_conf.intr_type = GPIO_INTR_DISABLE;
        io_conf.mode = GPIO_MODE_OUTPUT;
        io_conf.pin_bit_mask = selected_gpios;
        io_conf.pull_down_en = GPIO_PULLDOWN_DISABLE;
        io_conf.pull_up_en = GPIO_PULLUP_DISABLE;
        BO_TRY(gpio_config(&io_conf));

        BO_TRY(gpio_set_level(CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO, 0));
    }
#endif // CONFIG_LYFI_FAN_CTRL_SHUTDOWN_ENABLED

    {
        nvs_handle_t nvs_handle;
        BO_TRY(bo_nvs_factory_open(NVS_FAN_NAMESPACE, NVS_READWRITE, &nvs_handle));
        uint8_t use_pwm_fan = 0;
        int rc = nvs_get_u8(nvs_handle, FAN_NVS_KEY_USE_PWM, &use_pwm_fan);
        if (rc == 0) {
            _settings.use_pwm_fan = use_pwm_fan;
        }
        else {
            _settings.use_pwm_fan = 0;
        }
        bo_nvs_close(nvs_handle);
    }

    BO_TRY(rmtpwm_init());

    if (!_settings.use_pwm_fan) {
#if SOC_DAC_SUPPORTED
        ESP_LOGI(TAG, "Fan driver using DAC, channel=%u", CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL);
        BO_TRY(dac_output_enable(CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL));
#endif
    }

    else {
#if !SOC_DAC_SUPPORTED
        BO_TRY(rmtpwm_set_dac_duty(0));
#endif
    }

    BO_TRY(fan_set_power(FAN_POWER_MAX));

    ESP_LOGI(TAG, "Fan driver initizlied.");
    return 0;
}

int fan_set_power(uint8_t value)
{
    if (value > FAN_POWER_MAX) {
        value = FAN_POWER_MAX;
    }

    if (_status.power == value) {
        return 0;
    }

    _status.power = value;

#if CONFIG_LYFI_FAN_CTRL_SHUTDOWN_ENABLED
    if (value == 0) {
        BO_TRY(gpio_set_level(CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO, 0));
    }
    else {
        BO_TRY(gpio_set_level(CONFIG_LYFI_FAN_CTRL_SHUTDOWN_GPIO, 1));
    }
#endif // LYFI_FAN_CTRL_SHUTDOWN_ENABLED

    if (_settings.use_pwm_fan) {
        BO_TRY(rmtpwm_set_pwm_duty(value));
        ESP_LOGI(TAG, "Set fan power, method: PWM, power=%u%%", value);
    }
    else {

#if SOC_DAC_SUPPORTED
        // Built-in DAC
        {
            // TODO FIXME magic numbers
            uint8_t dac_value = 200 - (value * FAN_POWER_MAX / 80);
            if (value == 0) {
                dac_value = 0xFF;
            }
            int dac_value = value;
            BO_TRY(dac_output_voltage(CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL, dac_value));
            ESP_LOGI(TAG, "Set fan power, method: DAC, power=%u/100, DAC-value=%hhu", value, dac_value);
        }
#else
        // PWMDAC
        {
            // 80% ~= 3V, 30% ~= 12V
            int duty = (int)FAN_POWER_MAX - (int)value;
            duty = PWMDAC_FAN_MIN_DUTY + duty * (PWMDAC_FAN_MAX_DUTY - PWMDAC_FAN_MIN_DUTY) / FAN_POWER_MAX;

            if (duty <= PWMDAC_FAN_MIN_DUTY) {
                duty = FAN_POWER_MIN;
            }
            if (duty >= PWMDAC_FAN_MAX_DUTY) {
                duty = FAN_POWER_MAX;
            }
            BO_TRY(rmtpwm_set_dac_duty((uint8_t)duty));
            ESP_LOGI(TAG, "Set fan power, method: PWM DAC, power=%d, PWM-DAC_duty=%d", value, duty);
        }
#endif // CONFIG_IDF_TARGET_ESP32C3
    }

    return 0;
}

uint8_t fan_get_power() { return _status.power; }

const struct fan_status* fan_get_status() { return &_status; }

const struct fan_settings* fan_get_settings() { return &_settings; }