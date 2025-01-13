#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#include <esp_log.h>

#include "drvfx/kernel/common.h"
#include "drvfx/drvfx.h"

#define TAG "drvfx-init"

extern const struct drvfx_init_entry _drvfx_init_EARLY_start[];
extern const struct drvfx_init_entry _drvfx_init_EARLY_end[];
extern const struct drvfx_init_entry _drvfx_init_PRE_KERNEL_1_start[];
extern const struct drvfx_init_entry _drvfx_init_PRE_KERNEL_1_end[];
extern const struct drvfx_init_entry _drvfx_init_PRE_KERNEL_2_start[];
extern const struct drvfx_init_entry _drvfx_init_PRE_KERNEL_2_end[];
extern const struct drvfx_init_entry _drvfx_init_POST_KERNEL_start[];
extern const struct drvfx_init_entry _drvfx_init_POST_KERNEL_end[];
extern const struct drvfx_init_entry _drvfx_init_APPLICATION_start[];
extern const struct drvfx_init_entry _drvfx_init_APPLICATION_end[];

enum init_level {
    DRVFX_INIT_LEVEL_EARLY = 0,
    DRVFX_INIT_LEVEL_PRE_KERNEL_1,
    DRVFX_INIT_LEVEL_PRE_KERNEL_2,
    DRVFX_INIT_LEVEL_POST_KERNEL,
    DRVFX_INIT_LEVEL_APPLICATION,
};

static void drvfx_sys_init_run_level(enum init_level level)
{
    static const struct drvfx_init_entry* levels[] = {
        // EARLY pair
        _drvfx_init_EARLY_start,
        _drvfx_init_EARLY_end,

        // PRE_KERNEL_1 pair
        _drvfx_init_PRE_KERNEL_1_start,
        _drvfx_init_PRE_KERNEL_1_end,

        // PRE_KRENEL_2 pair
        _drvfx_init_PRE_KERNEL_2_start,
        _drvfx_init_PRE_KERNEL_2_end,

        // POST_KERNEL pair
        _drvfx_init_POST_KERNEL_start,
        _drvfx_init_POST_KERNEL_end,

        // APPLICATION pair
        _drvfx_init_APPLICATION_start,
        _drvfx_init_APPLICATION_end,
    };

    int pos = level * 2;
    for (const struct drvfx_init_entry* entry = levels[pos]; entry != levels[pos + 1]; entry++) {
        const struct drvfx_device* dev = entry->dev;
        int rc = entry->init(dev);

        if (dev != NULL) {
            /* Mark device initialized.  If initialization
             * failed, record the error condition.
             */
            if (rc != 0) {
                dev->state->init_res = rc;
                ESP_LOGE(TAG, "Failed to initialize: %s", dev->name);
            }
            dev->state->initialized = true;
        }
    }
}

static void __attribute__((constructor, used)) drvfx_kernel_init()
{
    ESP_LOGI(TAG, "Kernel initializing...");
    drvfx_sys_init_run_level(DRVFX_INIT_LEVEL_EARLY);
    drvfx_sys_init_run_level(DRVFX_INIT_LEVEL_PRE_KERNEL_1);
    drvfx_sys_init_run_level(DRVFX_INIT_LEVEL_PRE_KERNEL_2);
    drvfx_sys_init_run_level(DRVFX_INIT_LEVEL_POST_KERNEL);
    ESP_LOGI(TAG, "Kernel initialized.");
}

static void drvfx_userland_init()
{
    ESP_LOGI(TAG, "User land initializing...");

    drvfx_sys_init_run_level(DRVFX_INIT_LEVEL_APPLICATION);

    ESP_LOGI(TAG, "Main thread initialized.");
}

void app_main()
{
    //
    drvfx_userland_init();
}