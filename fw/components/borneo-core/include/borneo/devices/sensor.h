#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct sensor_api {
    int (*fetch_sample)(const struct drvfx_device* dev);
    int (*get_value)(const struct drvfx_device* dev, int32_t* value);
};

__SYSCALL int sensor_fetch_sample(const struct drvfx_device* dev)
{
    const struct sensor_api* api = dev ? dev->api : NULL;
    if (api == NULL) {
        return -ENOSYS;
    }
    return api->fetch_sample(dev);
}

__SYSCALL int sensor_get_value(const struct drvfx_device* dev, int32_t* value)
{
    const struct sensor_api* api = dev ? dev->api : NULL;
    if (api == NULL) {
        return -ENOSYS;
    }
    return api->get_value(dev, value);
}

#ifdef __cplusplus
}
#endif