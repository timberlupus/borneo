

#include <esp_check.h>
#include <esp_log.h>
#include <sys/errno.h>
#include <driver/rmt_tx.h>
#include <driver/gpio.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <drvfx/drvfx.h>
#include <borneo/system.h>

#include "rmtpwm.h"

static const char* TAG = "rmtpwm";

#define RMTPWM_FREQ_HZ 25000 // 25 kHz PWM
#define RMT_PWM_RESOLUTION_HZ 10000000 // 10MHz resolution

static size_t rmt_encode_pwm(rmt_encoder_t* encoder, rmt_channel_handle_t channel, const void* primary_data,
                             size_t data_size, rmt_encode_state_t* ret_state);
static esp_err_t rmt_del_pwm_encoder(rmt_encoder_t* encoder);
static esp_err_t rmt_pwm_encoder_reset(rmt_encoder_t* encoder);

static int rmtpwm_set_duty_internal(rmtpwm_generator_t* pwm, uint8_t duty);

/* Each PWM instance now contains its own encoder state */
#if CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT
static rmtpwm_generator_t s_pwm = { 0 };
#endif // CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT

#if !SOC_DAC_SUPPORTED && CONFIG_LYFI_FAN_CTRL_VREG_SUPPORT
static rmtpwm_generator_t s_dac = { 0 };
#endif // !SOC_DAC_SUPPORTED

static int _rmtpwm_init(const struct drvfx_device* dev)
{
    ESP_LOGI(TAG, "RMT PWM Sub-system initializing...");

#if CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT
    ESP_LOGI(TAG, "Create RMT TX channel (GPIO%u) for fan PWM...", CONFIG_LYFI_FAN_CTRL_PWM_GPIO);
    rmtpwm_encoder_config_t pwm_config = {
        .resolution = RMT_PWM_RESOLUTION_HZ,
        .pwm_freq = RMTPWM_FREQ_HZ,
        .gpio_num = CONFIG_LYFI_FAN_CTRL_PWM_GPIO,
    };
    BO_TRY(rmtpwm_generator_init(&s_pwm, &pwm_config));
#endif // CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT

    return 0;
}

int rmtpwm_generator_init(rmtpwm_generator_t* pwm, const rmtpwm_encoder_config_t* config)
{
    if (pwm == NULL || config == NULL) {
        return -EINVAL;
    }

    /* Initialize encoder part */
    pwm->base.encode = rmt_encode_pwm;
    pwm->base.del = rmt_del_pwm_encoder;
    pwm->base.reset = rmt_pwm_encoder_reset;
    pwm->resolution = config->resolution;
    pwm->ticks_per_period = pwm->resolution / config->pwm_freq; // Precompute per-instance frequency
    if (pwm->ticks_per_period == 0) {
        pwm->ticks_per_period = 1;
    }

    esp_err_t ret = ESP_OK;
    rmt_copy_encoder_config_t copy_encoder_config = {};
    ESP_GOTO_ON_ERROR(rmt_new_copy_encoder(&copy_encoder_config, &pwm->copy_encoder), err, TAG,
                      "create copy encoder failed");

    /* Initialize channel part */
    rmt_transmit_config_t tx_config = {
        .loop_count = -1,
    };
    pwm->mutex = xSemaphoreCreateMutexStatic(&pwm->mutex_buffer);
    rmt_tx_channel_config_t tx_chan_config = {
        .clk_src = RMT_CLK_SRC_DEFAULT, // select source clock
        .gpio_num = config->gpio_num,
#if CONFIG_IDF_TARGET_ESP32C3
        .mem_block_symbols = 48,
#else
        .mem_block_symbols = 64,
#endif
        .resolution_hz = config->resolution,
        .trans_queue_depth = 8, // set the maximum number of transactions that can pend in the background
    };
    BO_TRY_ESP(rmt_new_tx_channel(&tx_chan_config, &pwm->rmt_channel));
    BO_TRY_ESP(gpio_pullup_en(config->gpio_num));
    BO_TRY_ESP(rmt_enable(pwm->rmt_channel));
    BO_TRY_ESP(rmt_transmit(pwm->rmt_channel, &pwm->base, &pwm->duty, sizeof(pwm->duty), &tx_config));
    return 0;
err:
    if (pwm && pwm->copy_encoder) {
        rmt_del_encoder(pwm->copy_encoder);
        pwm->copy_encoder = NULL;
    }
    return ret;
}

int rmtpwm_set_duty(rmtpwm_generator_t* pwm, uint8_t duty) { return rmtpwm_set_duty_internal(pwm, duty); }

#if CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT

int rmtpwm_set_pwm_duty(uint8_t duty) { return rmtpwm_set_duty_internal(&s_pwm, duty); }

#endif // CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT

int rmtpwm_set_duty_internal(rmtpwm_generator_t* pwm, uint8_t duty)
{
    if (duty == pwm->duty) {
        return 0;
    }

    if (xSemaphoreTake(pwm->mutex, portMAX_DELAY) == pdTRUE) {
        BO_SEM_AUTO_RELEASE(pwm->mutex);

        pwm->duty = duty;
        // Precompute PWM parameters for performance
        uint32_t ticks_per_period = pwm->ticks_per_period;
        uint64_t numerator = (uint64_t)ticks_per_period * duty + RMTPWM_DUTY_MAX / 2;
        pwm->numerator = numerator;
        pwm->high_ticks = (uint32_t)(numerator / RMTPWM_DUTY_MAX);
        pwm->low_ticks = ticks_per_period - pwm->high_ticks;

        rmt_transmit_config_t tx_config = {
            .loop_count = -1,
        };

        BO_TRY_ESP(rmt_disable(pwm->rmt_channel));
        BO_TRY_ESP(rmt_enable(pwm->rmt_channel));
        BO_TRY_ESP(rmt_transmit(pwm->rmt_channel, &pwm->base, &pwm->duty, sizeof(pwm->duty), &tx_config));
    }
    else {
        return -EBUSY;
    }
    return 0;
}

static size_t rmt_encode_pwm(rmt_encoder_t* encoder, rmt_channel_handle_t channel, const void* primary_data,
                             size_t data_size, rmt_encode_state_t* ret_state)
{
    rmtpwm_generator_t* pwm = __containerof(encoder, rmtpwm_generator_t, base);
    rmt_encoder_handle_t copy_encoder = pwm->copy_encoder;
    rmt_encode_state_t session_state = RMT_ENCODING_RESET;

    // Use precomputed values for performance
    uint32_t high_ticks = pwm->high_ticks;
    uint32_t low_ticks = pwm->low_ticks;

    rmt_symbol_word_t pwm_rmt_symbol = {
        .level0 = 0,
        .duration0 = low_ticks,
        .level1 = 1,
        .duration1 = high_ticks,
    };

    size_t encoded_symbols
        = copy_encoder->encode(copy_encoder, channel, &pwm_rmt_symbol, sizeof(pwm_rmt_symbol), &session_state);
    *ret_state = session_state;
    return encoded_symbols;
}

static esp_err_t rmt_del_pwm_encoder(rmt_encoder_t* encoder)
{
    rmtpwm_generator_t* pwm = __containerof(encoder, rmtpwm_generator_t, base);
    /* Only delete the copy encoder; do not free the containing struct as instances are static */
    if (pwm->copy_encoder) {
        rmt_del_encoder(pwm->copy_encoder);
        pwm->copy_encoder = NULL;
    }
    return ESP_OK;
}

static esp_err_t rmt_pwm_encoder_reset(rmt_encoder_t* encoder)
{
    rmtpwm_generator_t* pwm = __containerof(encoder, rmtpwm_generator_t, base);
    rmt_encoder_reset(pwm->copy_encoder);
    return ESP_OK;
}
/* Note: encoder instances are now embedded in rmtpwm_generator_t instances and created via rmtpwm_instance_init() */

#if CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT || (CONFIG_LYFI_FAN_CTRL_VREG_SUPPORT && !SOC_DAC_SUPPORTED)

DRVFX_SUBSYS_INIT(_rmtpwm_init, DRVFX_INIT_KERNEL_DEFAULT_PRIORITY);

#endif
