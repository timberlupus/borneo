#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#define BO_MUST(expr)                                                                                                  \
    do {                                                                                                               \
        int __bo_rc = (expr);                                                                                          \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE("borneo-system", "errcode=%d, %s(%d): ", __bo_rc, __FUNCTION__, __LINE__);                        \
            bo_panic();                                                                                                \
        }                                                                                                              \
    } while (0)

#define BO_MUST_ISR(expr)                                                                                              \
    do {                                                                                                               \
        int __bo_rc = (expr);                                                                                          \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            bo_panic();                                                                                                \
        }                                                                                                              \
    } while (0)

#define BO_MUST_WITH(expr, log_tag, format, ...)                                                                       \
    do {                                                                                                               \
        int __bo_rc = (expr);                                                                                          \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE(log_tag, "errcode=%d, %s(%d): " format, __bo_rc, __FUNCTION__, __LINE__, ##__VA_ARGS__);          \
            bo_panic();                                                                                                \
        }                                                                                                              \
    } while (0)

#define BO_TRY(expression)                                                                                             \
    do {                                                                                                               \
        int __bo_rc = (expression);                                                                                    \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE("borneo-system", "errcode=%d, %s(%d)", __bo_rc, __FUNCTION__, __LINE__);                          \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0)

#define BO_TRY_ISR(expression)                                                                                         \
    do {                                                                                                               \
        int __bo_rc = (expression);                                                                                    \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0)

#define BO_TRY_WITH(expression, log_tag, format, ...)                                                                  \
    do {                                                                                                               \
        int _bo_rc = (expression);                                                                                     \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE(log_tag, "%s(%d): " format, __FUNCTION__, __LINE__, ##__VA_ARGS__);                               \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0);

#ifdef __cplusplus
}
#endif