#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct rtc_driver_api {
    int (*now)(const struct drvfx_device* dev, struct tm* now);
    int (*set_datetime)(const struct drvfx_device* dev, const struct tm* now);
    int (*is_halted)(const struct drvfx_device* dev, bool* halted);
    int (*halt)(const struct drvfx_device* dev);
};

#ifdef __cplusplus
}
#endif