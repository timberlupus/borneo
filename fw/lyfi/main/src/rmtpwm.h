#pragma once

#include <driver/rmt_tx.h>
#include <driver/gpio.h>

#ifdef __cplusplus
extern "C" {
#endif

#define RMTPWM_DUTY_MAX 255

/**
 * Combined RMT PWM structure.
 * Merges encoder state and channel state so each PWM instance is independent.
 */
typedef struct {
    /* Encoder base (must be first so __containerof works the same way) */
    rmt_encoder_t base;
    rmt_encoder_t* copy_encoder;
    uint32_t resolution;
    uint32_t ticks_per_period; ///< Precomputed for performance
    uint64_t numerator; ///< Precomputed numerator for duty calculation
    uint32_t high_ticks; ///< Precomputed high ticks
    uint32_t low_ticks; ///< Precomputed low ticks

    /* Channel state */
    rmt_channel_handle_t rmt_channel;
    uint32_t duty;
    SemaphoreHandle_t mutex;
    StaticSemaphore_t mutex_buffer;
} rmtpwm_generator_t;

/**
 * @brief Type of RMT PWM encoder configuration
 */
typedef struct {
    uint32_t resolution; /*!< Encoder resolution, in Hz */
    uint32_t pwm_freq; /*!< PWM frequency for this instance, in Hz */
    gpio_num_t gpio_num; /*!< GPIO pin for this instance */
} rmtpwm_encoder_config_t;

int rmtpwm_generator_init(rmtpwm_generator_t* pwm, const rmtpwm_encoder_config_t* config);

int rmtpwm_set_duty(rmtpwm_generator_t* pwm, uint8_t duty);

#if CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT
int rmtpwm_set_pwm_duty(uint8_t duty);
#endif // CONFIG_LYFI_FAN_CTRL_PWM_SUPPORT

#ifdef __cplusplus
}
#endif