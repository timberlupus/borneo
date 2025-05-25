#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define RMTPWM_DUTY_MAX 100

int rmtpwm_init();

#if !SOC_DAC_SUPPORTED
int rmtpwm_dac_init();
int rmtpwm_set_dac_duty(uint8_t duty);
#endif

#if CONFIG_LYFI_FAN_CTRL_PWM_ENABLED
int rmtpwm_pwm_init();
int rmtpwm_set_pwm_duty(uint8_t duty);
#endif // CONFIG_LYFI_FAN_CTRL_PWM_ENABLED

#ifdef __cplusplus
}
#endif