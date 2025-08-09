#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define BO_ADC_WINDOW_SIZE 7

int bo_adc_channel_config(adc_channel_t channel);
int bo_adc_read_mv(adc_channel_t channel, int* value_mv);
int bo_adc_read_mv_filtered(adc_channel_t channel, int* value_mv);

#ifdef __cplusplus
}
#endif