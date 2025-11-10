#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define FPWM_DUTY_MIN 0x00
#define FPWM_DUTY_MAX 0xFF

struct drvfx_device;

struct fpwm_driver_api {
    int (*set_duty)(const struct drvfx_device* dev, uint8_t duty);
};

__SYSCALL int fpwm_set_duty(const struct drvfx_device* dev, uint8_t duty)
{
    const struct fpwm_driver_api* api = dev ? dev->api : NULL;
    if (api == NULL) {
        return -ENOSYS;
    }
    return api->set_duty(dev, duty);
}

#ifdef __cplusplus
}
#endif