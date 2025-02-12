#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int rmtpwm_init();

int rmtpwm_set_pwm_duty(uint8_t duty);

#if CONFIG_IDF_TARGET_ESP32C3 || CONFIG_IDF_TARGET_ESP32C6
int rmtpwm_set_dac_duty(uint8_t duty);
#endif


#ifdef __cplusplus
}
#endif