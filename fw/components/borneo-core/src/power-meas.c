
#include <freertos/FreeRTOS.h>
#include <freertos/event_groups.h>
#include <freertos/task.h>

#include <esp_timer.h>
#include <esp_attr.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_sntp.h>
#include <esp_system.h>
#include <driver/gpio.h>
#include <esp_adc/adc_oneshot.h>

#include "borneo/common.h"
#include "borneo/system.h"
#include "borneo/devices/adc.h"
#include "borneo/power-meas.h"

#define TAG "power_meas"

int bo_power_meas_init()
{
    ESP_LOGI(TAG, "Initializing power measurement...");

    BO_TRY(bo_adc_channel_config(CONFIG_BORNEO_MEAS_VOLTAGE_ADC_CHANNEL));
    BO_TRY(bo_adc_channel_config(CONFIG_BORNEO_MEAS_CURRENT_ADC_CHANNEL));

    return 0;
}

int bo_power_volt_read(int* voltage)
{
    int adc_mv;
    BO_TRY(bo_adc_read_mv(CONFIG_BORNEO_MEAS_VOLTAGE_ADC_CHANNEL, &adc_mv));
    *voltage = adc_mv;
    return 0;
}
int bo_power_current_read(int* current)
{
    int adc_mv;
    BO_TRY(bo_adc_read_mv(CONFIG_BORNEO_MEAS_CURRENT_ADC_CHANNEL, &adc_mv));
    *current = adc_mv;
    return 0;
}
