

#include <esp_check.h>
#include <esp_log.h>
#include <sys/errno.h>
#include <driver/rmt_tx.h>
#include <driver/gpio.h>
#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <borneo/system.h>

#include "rmtpwm.h"

static const char* TAG = "rmtpwm";

#define RMTPWM_FREQ_HZ 19000 // 19 kHz PWM
#define RMT_PWM_RESOLUTION_HZ 10000000 // 10MHz resolution

typedef struct {
    rmt_encoder_t base;
    rmt_encoder_t* copy_encoder;
    uint32_t resolution;
} rmt_pwm_encoder_t;

/**
 * @brief Type of RMT PWM encoder configuration
 */
typedef struct {
    uint32_t resolution; /*!< Encoder resolution, in Hz */
} rmt_pwm_encoder_config_t;

struct rmtpwm_channel {
    rmt_channel_handle_t rmt_channel;
    uint32_t duty;
    SemaphoreHandle_t mutex;
    StaticSemaphore_t mutex_buffer;
};

/**
 * @brief Create RMT encoder for encoding PWM duty into RMT symbols
 *
 * @param[in] config Encoder configuration
 * @param[out] ret_encoder Returned encoder handle
 * @return
 *      - ESP_ERR_INVALID_ARG for any invalid arguments
 *      - ESP_ERR_NO_MEM out of memory when creating PWM encoder
 *      - ESP_OK if creating encoder successfully
 */
static int rmt_new_pwm_encoder(const rmt_pwm_encoder_config_t* config, rmt_encoder_handle_t* ret_encoder);

static int rmtpwm_set_duty_internal(struct rmtpwm_channel* channel, uint8_t duty);

static rmt_encoder_handle_t s_pwm_encoder = NULL;

#if CONFIG_LYFI_FAN_CTRL_PWM_ENABLED
static struct rmtpwm_channel s_pwm_channel = { 0 };
#endif // CONFIG_LYFI_FAN_CTRL_PWM_ENABLED

#if !SOC_DAC_SUPPORTED
static struct rmtpwm_channel s_dac_channel = { 0 };
#endif // !SOC_DAC_SUPPORTED

int rmtpwm_init()
{
    ESP_LOGI(TAG, "RMT PWM Sub-system initializing...");

    ESP_LOGI(TAG, "Install RMT PWM encoder");
    rmt_pwm_encoder_config_t encoder_config = {
        .resolution = RMT_PWM_RESOLUTION_HZ,
    };
    BO_TRY(rmt_new_pwm_encoder(&encoder_config, &s_pwm_encoder));
    return 0;
}

#if !SOC_DAC_SUPPORTED
int rmtpwm_dac_init()
{
    ESP_LOGI(TAG, "Create RMT TX channel (GPIO%u) for fan PWM-DAC...", CONFIG_LYFI_FAN_CTRL_PWMDAC_GPIO);
    rmt_transmit_config_t tx_config = {
        .loop_count = -1,
    };
    s_dac_channel.mutex = xSemaphoreCreateMutexStatic(&s_dac_channel.mutex_buffer);
    rmt_tx_channel_config_t fan_dac_tx_chan_config = {
        .clk_src = RMT_CLK_SRC_DEFAULT, // select source clock
        .gpio_num = CONFIG_LYFI_FAN_CTRL_PWMDAC_GPIO,
        .mem_block_symbols = 48, // DO NOT CHANGE THIS!!!
        .resolution_hz = RMT_PWM_RESOLUTION_HZ,
        .trans_queue_depth = 8, // set the maximum number of transactions that can pend in the background
    };
    BO_TRY(rmt_new_tx_channel(&fan_dac_tx_chan_config, &s_dac_channel.rmt_channel));
    BO_TRY(gpio_pullup_en(CONFIG_LYFI_FAN_CTRL_PWMDAC_GPIO));
    BO_TRY(rmt_enable(s_dac_channel.rmt_channel));
    BO_TRY(rmt_transmit(s_dac_channel.rmt_channel, s_pwm_encoder, &s_dac_channel.duty, sizeof(s_dac_channel.duty),
                        &tx_config));

    return 0;
}
#endif

#if CONFIG_LYFI_FAN_CTRL_PWM_ENABLED

int rmtpwm_pwm_init()
{
    rmt_transmit_config_t tx_config = {
        .loop_count = -1,
    };
    ESP_LOGI(TAG, "Create RMT TX channel (GPIO%u) for fan PWM...", CONFIG_LYFI_FAN_CTRL_PWM_GPIO);
    s_pwm_channel.mutex = xSemaphoreCreateMutexStatic(&s_pwm_channel.mutex_buffer);
    rmt_tx_channel_config_t fan_pwm_tx_chan_config = {
        .clk_src = RMT_CLK_SRC_DEFAULT, // select source clock
        .gpio_num = CONFIG_LYFI_FAN_CTRL_PWM_GPIO,
        .mem_block_symbols = 48, // DO NOT CHANGE THIS!!!
        .resolution_hz = RMT_PWM_RESOLUTION_HZ,
        .trans_queue_depth = 8, // set the maximum number of transactions that can pend in the background
    };
    BO_TRY(rmt_new_tx_channel(&fan_pwm_tx_chan_config, &s_pwm_channel.rmt_channel));
    BO_TRY(rmt_enable(s_pwm_channel.rmt_channel));
    BO_TRY(rmt_transmit(s_pwm_channel.rmt_channel, s_pwm_encoder, &s_pwm_channel.duty, sizeof(s_pwm_channel.duty),
                        &tx_config));

    return 0;
}

int rmtpwm_set_pwm_duty(uint8_t duty)
{
    if (duty >= RMTPWM_DUTY_MAX) {
        return -EINVAL;
    }
    return rmtpwm_set_duty_internal(&s_pwm_channel, duty);
}

#endif // CONFIG_LYFI_FAN_CTRL_PWM_ENABLED

#if !SOC_DAC_SUPPORTED
int rmtpwm_set_dac_duty(uint8_t duty)
{
    if (duty > RMTPWM_DUTY_MAX) {
        return -EINVAL;
    }
    return rmtpwm_set_duty_internal(&s_dac_channel, duty);
}
#endif // SOC_DAC_SUPPORTED

int rmtpwm_set_duty_internal(struct rmtpwm_channel* channel, uint8_t duty)
{
    if (duty > RMTPWM_DUTY_MAX) {
        return -EINVAL;
    }

    if (duty == channel->duty) {
        return 0;
    }

    if (xSemaphoreTake(channel->mutex, portMAX_DELAY) == pdTRUE) {
        BO_SEM_AUTO_RELEASE(channel->mutex);

        channel->duty = duty;
        rmt_transmit_config_t tx_config = {
            .loop_count = -1,
        };

        BO_TRY(rmt_disable(channel->rmt_channel));
        BO_TRY(rmt_enable(channel->rmt_channel));
        BO_TRY(rmt_transmit(channel->rmt_channel, s_pwm_encoder, &channel->duty, sizeof(channel->duty), &tx_config));
    }
    else {
        return -EBUSY;
    }
    return 0;
}

static size_t rmt_encode_pwm(rmt_encoder_t* encoder, rmt_channel_handle_t channel, const void* primary_data,
                             size_t data_size, rmt_encode_state_t* ret_state)
{
    rmt_pwm_encoder_t* pwm_encoder = __containerof(encoder, rmt_pwm_encoder_t, base);
    rmt_encoder_handle_t copy_encoder = pwm_encoder->copy_encoder;
    rmt_encode_state_t session_state = RMT_ENCODING_RESET;
    uint32_t* duty = (uint32_t*)primary_data;
    uint32_t rmt_raw_symbol_duration = pwm_encoder->resolution / (RMTPWM_FREQ_HZ) / RMTPWM_DUTY_MAX;
    rmt_symbol_word_t pwm_rmt_symbol = {
        .level0 = 0,
        .duration0 = rmt_raw_symbol_duration * (RMTPWM_DUTY_MAX - (*duty)),
        .level1 = 1,
        .duration1 = rmt_raw_symbol_duration * (*duty),
    };
    size_t encoded_symbols
        = copy_encoder->encode(copy_encoder, channel, &pwm_rmt_symbol, sizeof(pwm_rmt_symbol), &session_state);
    *ret_state = session_state;
    return encoded_symbols;
}

static esp_err_t rmt_del_pwm_encoder(rmt_encoder_t* encoder)
{
    rmt_pwm_encoder_t* pwm_encoder = __containerof(encoder, rmt_pwm_encoder_t, base);
    rmt_del_encoder(pwm_encoder->copy_encoder);
    free(pwm_encoder);
    return ESP_OK;
}

static esp_err_t rmt_pwm_encoder_reset(rmt_encoder_t* encoder)
{
    rmt_pwm_encoder_t* pwm_encoder = __containerof(encoder, rmt_pwm_encoder_t, base);
    rmt_encoder_reset(pwm_encoder->copy_encoder);
    return ESP_OK;
}

esp_err_t rmt_new_pwm_encoder(const rmt_pwm_encoder_config_t* config, rmt_encoder_handle_t* ret_encoder)
{
    esp_err_t ret = ESP_OK;
    rmt_pwm_encoder_t* pwm_encoder = NULL;
    ESP_GOTO_ON_FALSE(config && ret_encoder, ESP_ERR_INVALID_ARG, err, TAG, "invalid argument");
    pwm_encoder = rmt_alloc_encoder_mem(sizeof(rmt_pwm_encoder_t));
    ESP_GOTO_ON_FALSE(pwm_encoder, ESP_ERR_NO_MEM, err, TAG, "no mem for RMT PWM encoder");
    pwm_encoder->base.encode = rmt_encode_pwm;
    pwm_encoder->base.del = rmt_del_pwm_encoder;
    pwm_encoder->base.reset = rmt_pwm_encoder_reset;
    pwm_encoder->resolution = config->resolution;
    rmt_copy_encoder_config_t copy_encoder_config = {};
    ESP_GOTO_ON_ERROR(rmt_new_copy_encoder(&copy_encoder_config, &pwm_encoder->copy_encoder), err, TAG,
                      "create copy encoder failed");
    *ret_encoder = &pwm_encoder->base;
    return ESP_OK;
err:
    if (pwm_encoder) {
        if (pwm_encoder->copy_encoder) {
            rmt_del_encoder(pwm_encoder->copy_encoder);
        }
        free(pwm_encoder);
    }
    return ret;
}
