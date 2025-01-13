#include <stdint.h>
#include <time.h>

#include <esp_system.h>
#include <esp_log.h>
#include <esp_event.h>

#include <drvfx/drvfx.h>

#include <borneo/system.h>
#include <borneo/common.h>

#include "led.h"
#include "fan.h"
#include "thermal.h"

#define TAG "lyfi_init"

static int _lyfi_init(const struct drvfx_device* dev)
{
    BO_TRY(fan_init());

    BO_TRY(thermal_init());

    BO_TRY(led_init());

    ESP_LOGI(TAG, "Borneo LyFi has been initialized successfully.");
    return 0;
}

static int _app_init()
{
    // At this point, power-on is complete, send the power-on completion message.
    bo_system_set_ready();
    return 0;
}

DRVFX_SYS_INIT(_lyfi_init, APPLICATION, DRVFX_INIT_APP_DEFAULT_PRIORITY);
DRVFX_SYS_INIT(_app_init, APPLICATION, DRVFX_INIT_APP_LOWEST_PRIORITY);