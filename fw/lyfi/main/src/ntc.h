#pragma once

#ifdef __cplusplus
extern "C" {
#endif
/* Declarations of this file */

#if CONFIG_LYFI_NTC_SUPPORT

enum {

    // NTC ADC 采样间隔
    NTC_SAMPLING_INTERVAL = 100,

    // 无效的温度
    NTC_BAD_TEMPERATURE = -127,
};

int ntc_init();
int ntc_read_temp(int* temp);

#endif // CONFIG_LYFI_NTC_SUPPORT

#ifdef __cplusplus
}
#endif
