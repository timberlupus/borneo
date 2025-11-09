#pragma once

#include <esp_adc/adc_oneshot.h>

#include <drvfx/drvfx.h>

#ifdef __cplusplus
extern "C" {
#endif

struct adc_driver_api {
    int (*read_mv)(const struct drvfx_device* dev, adc_channel_t channel, int32_t* mv);
};

__SYSCALL int adc_read_mv(const struct drvfx_device* dev, adc_channel_t channel, int32_t* mv)
{
    const struct adc_driver_api* api = dev ? dev->api : NULL;
    if (api == NULL) {
        return -ENOSYS;
    }
    return api->read_mv(dev, channel, mv);
}

#ifdef __cplusplus
}
#endif