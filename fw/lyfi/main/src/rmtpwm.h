#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int rmtpwm_init();

#if !SOC_DAC_SUPPORTED
int rmtpwm_dac_init();
int rmtpwm_set_dac_duty(uint8_t duty);
#endif

int rmtpwm_pwm_init();
int rmtpwm_set_pwm_duty(uint8_t duty);

#ifdef __cplusplus
}
#endif