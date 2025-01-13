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

#if CONFIG_IDF_TARGET_ESP32 || CONFIG_IDF_TARGET_ESP32S2
#include <driver/dac.h>
#endif

#include <borneo/system.h>
#include <borneo/nvs.h>

#include "fan.h"

#if CONFIG_IDF_TARGET_ESP32C3
#define NVS_FAN_NAMESPACE "fan"
#define FAN_NVS_KEY_USE_PWM "use_pwm"
#endif // CONFIG_IDF_TARGET_ESP32C3

#define TAG "fan"

static struct fan_status _status = { 0 };
static struct fan_settings _settings = { 0 };
static ledc_channel_config_t _channel_config = { 0 };

// 应该支持 DAC/PWM/PWN_DAC
// 三种调速风扇

int fan_init()
{
    ESP_LOGI(TAG, "Initializing fan driver...");

    // 初始化风扇输出开关脚
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

    // 初始化风扇配置
    {
        // 读取配置
        nvs_handle_t nvs_handle;
        BO_TRY(bo_nvs_factory_open(NVS_FAN_NAMESPACE, NVS_READWRITE, &nvs_handle));
        uint8_t use_pwm_fan = 0;
        int rc = nvs_get_u8(nvs_handle, FAN_NVS_KEY_USE_PWM, &use_pwm_fan);
        if (rc == 0) {
            _settings.use_pwm_fan = use_pwm_fan;
        }
        else {
            // 默认不用 PWM 风扇
            _settings.use_pwm_fan = 0;
        }
        bo_nvs_close(nvs_handle);
    }

    // 初始化 PWM 定时器
    {
        ESP_LOGI(TAG, "Initializing PWM timer.");

        ledc_timer_config_t ledc_timer = {
            .duty_resolution = LEDC_TIMER_8_BIT, // PWM分辨率
            .freq_hz = 25000, // 频率 25k
#if CONFIG_IDF_TARGET_ESP32S2 || CONFIG_IDF_TARGET_ESP32C3
            .speed_mode = LEDC_LOW_SPEED_MODE, // 速度
            .timer_num = LEDC_TIMER_2, // 选择定时器
#else
            .speed_mode = LEDC_HIGH_SPEED_MODE, // 速度
            .timer_num = LEDC_TIMER_1, // 选择定时器
#endif
        };

        BO_TRY(ledc_timer_config(&ledc_timer));
        ESP_LOGI(TAG, "PWM timer initialized.");
    }

    {
        // C3 芯片只能 PWM 和 PWMDAC 选一个
#if CONFIG_IDF_TARGET_ESP32C3
        {
            uint16_t pwm_gpio
                = _settings.use_pwm_fan ? CONFIG_LYFI_FAN_CTRL_PWM_GPIO : CONFIG_LYFI_FAN_CTRL_PWMDAC_GPIO;
            ESP_LOGI(TAG, "Fan driver PWM, GPIO=%u, channel=%u", pwm_gpio, CONFIG_LYFI_FAN_CTRL_PWM_CHANNEL);
            _channel_config.gpio_num = pwm_gpio;
        }
#else
        ESP_LOGI(TAG, "Fan driver PWM, GPIO=%u, channel=%u", CONFIG_LYFI_FAN_CTRL_PWM_GPIO,
                 CONFIG_LYFI_FAN_CTRL_PWM_CHANNEL);
        _channel_config.gpio_num = CONFIG_LYFI_FAN_CTRL_PWM_GPIO;
#endif // CONFIG_IDF_TARGET_ESP32C3
        _channel_config.hpoint = 0;
#if CONFIG_IDF_TARGET_ESP32S2 || CONFIG_IDF_TARGET_ESP32C3
        _channel_config.speed_mode = LEDC_LOW_SPEED_MODE;
        _channel_config.timer_sel = LEDC_TIMER_2;
#else
        _channel_config.speed_mode = LEDC_HIGH_SPEED_MODE;
        _channel_config.timer_sel = LEDC_TIMER_1;
#endif
        // Set LED Controller with previously prepared configuration
        _channel_config.duty = 0xFF; // 没有防倒灌二极管的话绝对不能太小，否则输出电压很高！！！
        _channel_config.channel = CONFIG_LYFI_FAN_CTRL_PWM_CHANNEL;
        BO_TRY(ledc_channel_config(&_channel_config));
    }

#if CONFIG_IDF_TARGET_ESP32 || CONFIG_IDF_TARGET_ESP32S2
    if (!_settings.use_pwm_fan) {
        ESP_LOGI(TAG, "Fan driver using DAC, channel=%u", CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL);
        BO_TRY(dac_output_enable(CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL));
    }
#endif

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

        int duty = 255 * value / FAN_POWER_MAX;
        BO_TRY(ledc_set_duty(_channel_config.speed_mode, _channel_config.channel, duty));
        BO_TRY(ledc_update_duty(_channel_config.speed_mode, _channel_config.channel));
        ESP_LOGI(TAG, "Set fan power, method: PWM DAC, power=%u/100, duty=%d/255", value, duty);
    }
    else {

#if CONFIG_IDF_TARGET_ESP32 || CONFIG_IDF_TARGET_ESP32S2
        // 有 DAC 的就用 DAC 设置
        {
            // TODO FIXME
            uint8_t dac_value = 200 - (value * FAN_POWER_MAX / 80);
            if (value == 0) {
                dac_value = 0xFF;
            }
            int dac_value = value;
            BO_TRY(dac_output_voltage(CONFIG_LYFI_FAN_CTRL_DAC_CHANNEL, dac_value));
            ESP_LOGD(TAG, "Set fan power, method: DAC, power=%u/100, DAC-value=%hhu", value, dac_value);
        }
#else
        // 没有 DAC 的用 PWMDAC
        {
            uint8_t duty = 60 + (FAN_POWER_MAX - value);
            BO_TRY(ledc_set_duty(_channel_config.speed_mode, _channel_config.channel, duty));
            BO_TRY(ledc_update_duty(_channel_config.speed_mode, _channel_config.channel));
            ESP_LOGD(TAG, "Set fan power, method: PWM DAC, power=%hhu/100, PWM-DAC_duty=%hhu/255", value, duty);
        }
#endif // CONFIG_IDF_TARGET_ESP32C3
    }

    return 0;
}

uint8_t fan_get_power() { return _status.power; }

const struct fan_status* fan_get_status() { return &_status; }

const struct fan_settings* fan_get_settings() { return &_settings; }