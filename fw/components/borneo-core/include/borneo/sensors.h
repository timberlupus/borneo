#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#include <stddef.h>

struct drvfx_device;

size_t sensors_get_device_count(void);
const struct drvfx_device** sensors_get_devices(void);

#ifdef __cplusplus
}
#endif