
#include <string.h>
#include <stdint.h>
#include <stdbool.h>
#include <stdlib.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>

#include <esp_system.h>
#include <esp_err.h>
#include <esp_log.h>
#include <driver/ledc.h>
#include <nvs_flash.h>
#include <driver/gpio.h>

#include <driver/dac.h>

#include <drvfx/drvfx.h>
#include <borneo/system.h>

#if CONFIG_LYFI_FAN_CTRL_VREG_DEVICE_DAC

#endif // CONFIG_LYFI_FAN_CTRL_VREG_DEVICE_DAC