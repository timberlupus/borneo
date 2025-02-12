#pragma once

#ifdef __cplusplus
extern "C" {
#endif

adc_cali_handle_t bo_adc_get_cali();
int bo_adc_channel_config(adc_channel_t channel);
int bo_adc_read_mv(adc_channel_t channel, int* value_mv);

#ifdef __cplusplus
}
#endif