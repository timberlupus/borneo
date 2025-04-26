#pragma once

#ifdef __cplusplus
extern "C" {
#endif

ESP_EVENT_DECLARE_BASE(LYFI_LED_EVENTS);

enum {
    LYFI_LED_STATE_CHANGED,
    LYFI_LED_NOTIFY_NIGHTLIGHT_STATE,
};

#ifdef __cplusplus
}
#endif