#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct drvfx_device;

struct vreg_driver_api {
    int (*set_output)(const struct drvfx_device* dev, uint8_t percent);
};

__SYSCALL int vreg_set_output(const struct drvfx_device* dev, uint8_t percent)
{
    const struct vreg_driver_api* api = dev ? dev->api : NULL;
    if (api == NULL) {
        return -ENOSYS;
    }
    return api->set_output(dev, percent);
}

#ifdef __cplusplus
}
#endif