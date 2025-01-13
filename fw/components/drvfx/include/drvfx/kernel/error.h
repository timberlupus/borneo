#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define K_TRY(expression)                                                                                              \
    ({                                                                                                                 \
        int _rc = (expression);                                                                                        \
        if (_rc != 0) {                                                                                                \
            return _rc;                                                                                                \
        }                                                                                                              \
    })

#define K_TRY_OR_UNLOCK(expression, semi)                                                                              \
    ({                                                                                                                 \
        int _rc = (expression);                                                                                        \
        if (_rc != 0) {                                                                                                \
            xSemaphoreGive(semi);                                                                                      \
            return _rc;                                                                                                \
        }                                                                                                              \
    })

#define K_TRY_WITH_MESSAGE(expression, msg)                                                                               \
    ({                                                                                                                 \
        int _rc = (expression);                                                                                        \
        if (_rc != 0) {                                                                                                \
            ESP_LOGE("drvfx", "Error(%d): %s - %s:%d#%s", _rc, msg, __FILE__, __LINE__, __FUNCTION__); \
            return _rc;                                                                                                \
        }                                                                                                              \
    }

#ifdef __cplusplus
}
#endif