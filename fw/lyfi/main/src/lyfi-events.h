#pragma once

#ifdef __cplusplus
extern "C" {
#endif

ESP_EVENT_DECLARE_BASE(LYFI_LEDC_EVENTS);

enum {
    LYFI_LEDC_MODE_CHANGED,
    LYFI_LEDC_NOTIFY_NIGHTLIGHT_MODE,
};

#ifdef __cplusplus
}
#endif