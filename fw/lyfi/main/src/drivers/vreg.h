#pragma once

#include <drvfx/drvfx.h>

#ifdef __cplusplus
extern "C" {
#endif

struct vreg_driver_api {
    int (*set_duty)(const struct drvfx_device* dev, uint8_t duty);
};

__SYSCALL int vreg_set_duty(const struct drvfx_device* dev, uint8_t duty)
{
    const struct apwm_driver_api* api = dev ? dev->api : NULL;
    if (api == NULL) {
        return -ENOSYS;
    }
    return api->set_duty(dev, duty);
}

#ifdef __cplusplus
}
#endif