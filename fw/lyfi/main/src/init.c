#include <stdint.h>
#include <time.h>

#include <esp_system.h>
#include <esp_log.h>
#include <esp_event.h>

#include <drvfx/drvfx.h>

#include <borneo/system.h>
#include <borneo/common.h>

#include "led/led.h"
#include "fan.h"
#include "thermal.h"
#include "button.h"

#define TAG "lyfi_init"

static int _lyfi_init(const struct drvfx_device* dev)
{

#if CONFIG_LYFI_FAN_CTRL_ENABLED
    BO_TRY(fan_init());
#endif

#if CONFIG_LYFI_THERMAL_ENABLED
    BO_TRY(thermal_init());
#endif

    BO_TRY(led_init());

#if CONFIG_LYFI_PRESS_BUTTON_ENABLED
    BO_TRY(button_init());
#endif

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