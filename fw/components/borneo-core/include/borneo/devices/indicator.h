#pragma once

#ifdef __cplusplus
extern "C" {
#endif

enum {
    BO_INDICATOR_STATE_NORMAL = 0,
    BO_INDICATOR_STATE_FAULT,
    BO_INDICATOR_STATE_EMERGENCY_SHUTDOWN,
    BO_INDICATOR_STATE_NO_CONN,
};

int bo_indicator_init();

#ifdef __cplusplus
}
#endif