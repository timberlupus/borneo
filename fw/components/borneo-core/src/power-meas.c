
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

#if CONFIG_BORNEO_MEAS_VOLTAGE_ENABLED
    BO_TRY(bo_adc_channel_config(CONFIG_BORNEO_MEAS_VOLTAGE_ADC_CHANNEL));
#endif

#if CONFIG_BORNEO_MEAS_CURRENT_ENABLED
    BO_TRY(bo_adc_channel_config(CONFIG_BORNEO_MEAS_CURRENT_ADC_CHANNEL));
#endif

    return 0;
}

#if CONFIG_BORNEO_MEAS_VOLTAGE_ENABLED
int bo_power_volt_read(int* mv)
{
    if (mv == NULL) {
        return -EINVAL;
    }
    int adc_mv;
    BO_TRY(bo_adc_read_mv_filtered(CONFIG_BORNEO_MEAS_VOLTAGE_ADC_CHANNEL, &adc_mv));
    *mv = adc_mv * CONFIG_BORNEO_MEAS_VOLTAGE_FACTOR / 1000;
    return 0;
}
#endif

#if CONFIG_BORNEO_MEAS_CURRENT_ENABLED
int bo_power_current_read(int* ma)
{
    if (ma == NULL) {
        return -EINVAL;
    }
    int adc_mv;
    BO_TRY(bo_adc_read_mv_filtered(CONFIG_BORNEO_MEAS_CURRENT_ADC_CHANNEL, &adc_mv));
    *ma = adc_mv * 1000 / CONFIG_BORNEO_MEAS_CURRENT_FACTOR;
    return 0;
}
#endif
