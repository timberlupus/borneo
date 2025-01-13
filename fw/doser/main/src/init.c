#include <stdint.h>

#include <esp_system.h>
#include <esp_log.h>
#include <esp_event.h>

#include <drvfx/drvfx.h>

#include <borneo/system.h>

#include "pump.h"
#include "scheduler.h"

#define TAG "doser-init"

static int _doser_init(const struct drvfx_device* dev)
{
    ESP_LOGI(TAG, "Borneo Doser has been initialized successfully.");
    return 0;
}

static int _app_init()
{
    // At this point, power-on is complete, send the power-on completion message.
    bo_system_set_ready();
    return 0;
}

DRVFX_SYS_INIT(_doser_init, APPLICATION, DRVFX_INIT_APP_DEFAULT_PRIORITY);
DRVFX_SYS_INIT(_app_init, APPLICATION, DRVFX_INIT_APP_LOWEST_PRIORITY);