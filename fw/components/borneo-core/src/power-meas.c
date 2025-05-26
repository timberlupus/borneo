
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

#include "borneo/algo/filters.h"
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
    *mv = (adc_mv * CONFIG_BORNEO_MEAS_VOLTAGE_FACTOR + 500) / 1000;
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
    *ma = (adc_mv * 1000 + (CONFIG_BORNEO_MEAS_CURRENT_FACTOR / 2)) / CONFIG_BORNEO_MEAS_CURRENT_FACTOR;
    return 0;
}
#endif

#if CONFIG_BORNEO_MEAS_VOLTAGE_ENABLED && CONFIG_BORNEO_MEAS_CURRENT_ENABLED
int bo_power_read(int32_t* mw)
{
    if (mw == NULL) {
        return -EINVAL;
    }

    // TODO Add lock
    uint16_t v_adc_window[BO_ADC_WINDOW_SIZE];
    uint16_t c_adc_window[BO_ADC_WINDOW_SIZE];
    for (size_t i = 0; i < BO_ADC_WINDOW_SIZE; i++) {
        int adc_v, adc_c;
        BO_TRY(bo_adc_read_mv(CONFIG_BORNEO_MEAS_VOLTAGE_ADC_CHANNEL, &adc_v));
        BO_TRY(bo_adc_read_mv(CONFIG_BORNEO_MEAS_CURRENT_ADC_CHANNEL, &adc_c));
        if (adc_v == 0 || adc_v == 4095) {
            return -EIO;
        }
        if (adc_c == 0 || adc_c == 4095) {
            return -EIO;
        }
        v_adc_window[i] = (uint16_t)adc_v;
        c_adc_window[i] = (uint16_t)adc_c;
    }

    int value_mv;
    int value_ma;

    value_mv = median_filter_u16(v_adc_window, BO_ADC_WINDOW_SIZE);
    value_mv = (value_mv * CONFIG_BORNEO_MEAS_VOLTAGE_FACTOR + 500) / 1000;

    value_ma = median_filter_u16(c_adc_window, BO_ADC_WINDOW_SIZE);
    value_ma = (value_ma * 1000 + (CONFIG_BORNEO_MEAS_CURRENT_FACTOR / 2)) / CONFIG_BORNEO_MEAS_CURRENT_FACTOR;

    *mw = (value_mv * value_ma + 500) / 1000; // Convert to mW
    return 0;
}
#endif
