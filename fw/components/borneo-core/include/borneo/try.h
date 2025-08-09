#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// For ESP-IDF error name strings
#include "esp_err.h"

// Branch prediction hints (fallback if not provided by toolchain/SDK)
#ifndef likely
#define likely(x) __builtin_expect(!!(x), 1)
#endif
#ifndef unlikely
#define unlikely(x) __builtin_expect(!!(x), 0)
#endif

/**
 * Error handling helpers for functions that return 0 on success and non-zero on failure.
 *
 * Key properties:
 * - Each macro evaluates its expression exactly once (stored via GCC __auto_type).
 * - "TRY" macros return the error code to the caller on failure.
 * - "MUST" macros call bo_panic() on failure (do not return).
 * - "WITH" variants allow custom log tag and message format.
 * - ESP variants print esp_err_t name using esp_err_to_name().
 * - ISR variants avoid logging and simply panic/return as documented (safe for ISR).
 *
 * Conventions:
 * - Non-zero is treated as error.
 * - Logging includes function and line for quick pinpointing.
 * - Designed for GCC; uses __auto_type and __builtin_expect.
 */

/**
 * BO_MUST(expr)
 * Evaluate expr; on non-zero, log and call bo_panic().
 * Use when failure is unrecoverable and should reset/halt.
 *
 * Example:
 * @code
 * void must_init(void) {
 *     BO_MUST(esp_event_loop_create_default());
 *     BO_MUST(gpio_install_isr_service(0));
 * }
 * @endcode
 */
#define BO_MUST(expr)                                                                                                  \
    do {                                                                                                               \
        __auto_type __bo_rc = (expr);                                                                                  \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE("borneo-system", "errcode=%d, %s(%d): ", __bo_rc, __func__, __LINE__);                            \
            bo_panic();                                                                                                \
        }                                                                                                              \
    } while (0)

/**
 * BO_MUST_ISR(expr)
 * ISR-safe MUST: evaluate expr; on non-zero, call bo_panic() without logging.
 *
 * Example:
 * @code
 * void IRAM_ATTR isr_handler(void* arg) {
 *     BO_MUST_ISR(gpio_set_level(CONFIG_PIN, 1));
 * }
 * @endcode
 */
#define BO_MUST_ISR(expr)                                                                                              \
    do {                                                                                                               \
        __auto_type __bo_rc = (expr);                                                                                  \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            bo_panic();                                                                                                \
        }                                                                                                              \
    } while (0)

/**
 * BO_MUST_WITH(expr, log_tag, format, ...)
 * Like BO_MUST but with custom log tag and message.
 * The formatted message is appended after the standard prefix.
 *
 * Example:
 * @code
 * BO_MUST_WITH(nvs_commit(handle), "nvs", "while committing namespace '%s'", ns);
 * @endcode
 */
#define BO_MUST_WITH(expr, log_tag, format, ...)                                                                       \
    do {                                                                                                               \
        __auto_type __bo_rc = (expr);                                                                                  \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE(log_tag, "errcode=%d, %s(%d): " format, __bo_rc, __func__, __LINE__, ##__VA_ARGS__);              \
            bo_panic();                                                                                                \
        }                                                                                                              \
    } while (0)

/**
 * BO_TRY(expression)
 * Evaluate expression; on non-zero, log and return the error code.
 *
 * Example:
 * @code
 * esp_err_t app_init(void) {
 *     BO_TRY(gpio_config(&io_conf));
 *     BO_TRY(esp_event_handler_register(SOME_EVENTS, ESP_EVENT_ANY_ID, handler, NULL));
 *     return ESP_OK;
 * }
 * @endcode
 */
#define BO_TRY(expression)                                                                                             \
    do {                                                                                                               \
        __auto_type __bo_rc = (expression);                                                                            \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE("borneo-system", "errcode=%d, %s(%d)", __bo_rc, __func__, __LINE__);                              \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0)

/**
 * BO_TRY_ISR(expression)
 * ISR-safe TRY: evaluate expression; on non-zero, return the error code without logging.
 *
 * Example:
 * @code
 * int IRAM_ATTR isr_work(void) {
 *     BO_TRY_ISR(do_quick_isr_work());
 *     return 0;
 * }
 * @endcode
 */
#define BO_TRY_ISR(expression)                                                                                         \
    do {                                                                                                               \
        __auto_type __bo_rc = (expression);                                                                            \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0)

/**
 * BO_TRY_WITH(expression, log_tag, format, ...)
 * Like BO_TRY but with custom log tag and formatted message.
 *
 * Example:
 * @code
 * BO_TRY_WITH(cbor_encode_uint(enc, val), "cbor", "encoding '%s' key", key_name);
 * @endcode
 */
#define BO_TRY_WITH(expression, log_tag, format, ...)                                                                  \
    do {                                                                                                               \
        __auto_type __bo_rc = (expression);                                                                            \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE(log_tag, "errcode=%d, %s(%d): " format, __bo_rc, __func__, __LINE__, ##__VA_ARGS__);              \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0)

/**
 * BO_TRY_SILENT(expression)
 * Evaluate expression; on non-zero, return the error code without any logging.
 * Use when the caller is responsible for aggregating/reporting errors.
 *
 * Example:
 * @code
 * esp_err_t load_all(void) {
 *     BO_TRY_SILENT(load_a());
 *     BO_TRY_SILENT(load_b());
 *     return ESP_OK;
 * }
 * @endcode
 */
#define BO_TRY_SILENT(expression)                                                                                      \
    do {                                                                                                               \
        __auto_type __bo_rc = (expression);                                                                            \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0)

#define BO_MUST_ESP(expr)                                                                                              \
    do {                                                                                                               \
        __auto_type __bo_rc = (expr);                                                                                  \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE("borneo-system", "err=%s(%d), %s(%d): ", esp_err_to_name(__bo_rc), __bo_rc, __func__, __LINE__);  \
            bo_panic();                                                                                                \
        }                                                                                                              \
    } while (0)

/**
 * BO_MUST_ESP_WITH(expr, log_tag, format, ...)
 * MUST + ESP name + custom message.
 *
 * Example:
 * @code
 * BO_MUST_ESP_WITH(nvs_commit(handle), "nvs", "commit failed in ns=%s", ns);
 * @endcode
 */
#define BO_MUST_ESP_WITH(expr, log_tag, format, ...)                                                                   \
    do {                                                                                                               \
        __auto_type __bo_rc = (expr);                                                                                  \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE(log_tag, "err=%s(%d), %s(%d): " format, esp_err_to_name(__bo_rc), __bo_rc, __func__, __LINE__,    \
                     ##__VA_ARGS__);                                                                                   \
            bo_panic();                                                                                                \
        }                                                                                                              \
    } while (0)

/**
 * BO_TRY_ESP(expression)
 * TRY variant expecting esp_err_t: log error name and code, then return.
 *
 * Example:
 * @code
 * esp_err_t wifi_start(void) {
 *     BO_TRY_ESP(esp_wifi_init(&cfg));
 *     BO_TRY_ESP(esp_wifi_start());
 *     return ESP_OK;
 * }
 * @endcode
 */
#define BO_TRY_ESP(expression)                                                                                         \
    do {                                                                                                               \
        __auto_type __bo_rc = (expression);                                                                            \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE("borneo-system", "err=%s(%d), %s(%d)", esp_err_to_name(__bo_rc), __bo_rc, __func__, __LINE__);    \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0)

/**
 * BO_TRY_ESP_WITH(expression, log_tag, format, ...)
 * TRY + ESP name + custom message.
 *
 * Example:
 * @code
 * BO_TRY_ESP_WITH(esp_event_handler_register(EVT, ANY, cb, NULL), "event", "module=%s", mod);
 * @endcode
 */
#define BO_TRY_ESP_WITH(expression, log_tag, format, ...)                                                              \
    do {                                                                                                               \
        __auto_type __bo_rc = (expression);                                                                            \
        if (unlikely(__bo_rc != 0)) {                                                                                  \
            ESP_LOGE(log_tag, "err=%s(%d), %s(%d): " format, esp_err_to_name(__bo_rc), __bo_rc, __func__, __LINE__,    \
                     ##__VA_ARGS__);                                                                                   \
            return __bo_rc;                                                                                            \
        }                                                                                                              \
    } while (0)

/**
 * BO_TRY_GOTO_RC(expression, rcvar, label)
 * Evaluate expression and assign to rcvar; on non-zero, log and goto label.
 * Useful for single-exit cleanup flows while preserving the error code.
 *
 * Example:
 * @code
 * esp_err_t do_things(void) {
 *     esp_err_t rc = ESP_OK;
 *     handle_t h = NULL;
 *     BO_TRY_GOTO_RC(open_handle(&h), rc, cleanup);
 *     BO_TRY_GOTO_RC(do_work(h), rc, cleanup);
 * cleanup:
 *     if (h) close_handle(h);
 *     return rc;
 * }
 * @endcode
 */
#define BO_TRY_GOTO_RC(expression, rcvar, label)                                                                       \
    do {                                                                                                               \
        (rcvar) = (expression);                                                                                        \
        if (unlikely((rcvar) != 0)) {                                                                                  \
            ESP_LOGE("borneo-system", "errcode=%d, %s(%d)", (rcvar), __func__, __LINE__);                              \
            goto label;                                                                                                \
        }                                                                                                              \
    } while (0)

/**
 * BO_TRY_GOTO_RC_WITH(expression, rcvar, label, log_tag, format, ...)
 * Like BO_TRY_GOTO_RC with custom log tag and formatted message.
 *
 * Example:
 * @code
 * BO_TRY_GOTO_RC_WITH(write_blob(h, k, v), rc, cleanup, "nvs", "key=%s", k);
 * @endcode
 */
#define BO_TRY_GOTO_RC_WITH(expression, rcvar, label, log_tag, format, ...)                                            \
    do {                                                                                                               \
        (rcvar) = (expression);                                                                                        \
        if (unlikely((rcvar) != 0)) {                                                                                  \
            ESP_LOGE(log_tag, "errcode=%d, %s(%d): " format, (rcvar), __func__, __LINE__, ##__VA_ARGS__);              \
            goto label;                                                                                                \
        }                                                                                                              \
    } while (0)

#ifdef __cplusplus
}
#endif