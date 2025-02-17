#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int bo_adc_channel_config(adc_channel_t channel);
int bo_adc_read_mv(adc_channel_t channel, int* value_mv);

#ifdef __cplusplus
}
#endif