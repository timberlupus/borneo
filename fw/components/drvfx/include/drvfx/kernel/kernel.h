#pragma once

#ifdef __cplusplus
extern "C" {
#endif

ESP_EVENT_DECLARE_BASE(KERNEL_EVENTS);

/// @brief Kernel events
enum {
    KERNEL_EVENT_INITIALIZING = 0, ///< Power-on start initialization
    KERNEL_EVENT_ENTERING_SAFE_MODE, ///< Entering safe mode
    KERNEL_EVENT_READY ///< System initialized and ready to operate
};

typedef enum {
    KERNEL_MODE_INIT = 0,
    KERNEL_MODE_NORMAL = 1,
    KERNEL_MODE_SAFE = 2,
} kernel_mode_t;

void k_init();
void k_safe_mode(uint32_t reason);
uint32_t k_get_shutdown_reason();

kernel_mode_t k_get_mode();

#ifdef __cplusplus
}
#endif