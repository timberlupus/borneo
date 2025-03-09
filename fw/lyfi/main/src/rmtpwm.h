#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int rmtpwm_init();

int rmtpwm_set_pwm_duty(uint8_t duty);

#if !SOC_DAC_SUPPORTED
int rmtpwm_set_dac_duty(uint8_t duty);
#endif

#ifdef __cplusplus
}
#endif