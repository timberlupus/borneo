
#include <errno.h>
#include <nvs_flash.h>

#include "sdkconfig.h"

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
#include "borneo/nvs.h"

#define TAG "power_meas"

#if CONFIG_LYFI_MEAS_CURRENT_SUPPORT
#define LED_NVS_NS "led"
#define LED_NVS_KEY_MEAS_CURRENT_ENABLED "curr.en"

#ifndef CONFIG_LYFI_MEAS_CURRENT_OFFSET
#define CONFIG_LYFI_MEAS_CURRENT_OFFSET 0
#endif

struct power_meas_factory_settings {
    bool measurement_enabled;
};

static struct power_meas_factory_settings s_factory_settings = {
    .measurement_enabled = true,
};

static int factory_settings_load(void)
{
    nvs_handle_t nvs_handle;
    BO_TRY(bo_nvs_factory_open(LED_NVS_NS, NVS_READWRITE, &nvs_handle));
    BO_NVS_AUTO_CLOSE(nvs_handle);

    bool changed = false;
    uint8_t enabled = 1;

    BO_TRY(bo_nvs_get_or_set_u8(nvs_handle, LED_NVS_KEY_MEAS_CURRENT_ENABLED, &enabled, 1, &changed));

    if (changed) {
        BO_TRY(nvs_commit(nvs_handle));
    }

    s_factory_settings.measurement_enabled = (enabled != 0);

    return 0;
}
#endif

int lyfi_power_meas_init()
{
    ESP_LOGI(TAG, "Initializing LyFi power measurement...");

#if CONFIG_LYFI_MEAS_CURRENT_SUPPORT
    BO_TRY(factory_settings_load());
    if (!s_factory_settings.measurement_enabled) {
        ESP_LOGW(TAG, "Power measurement disabled by factory settings.");
        return 0;
    }
    BO_TRY(bo_adc_channel_config(CONFIG_LYFI_MEAS_CURRENT_ADC_CHANNEL));
#endif

    return 0;
}

#if CONFIG_LYFI_MEAS_CURRENT_SUPPORT
int lyfi_power_current_read(int* ma)
{
    if (ma == NULL) {
        return -EINVAL;
    }
    if (!s_factory_settings.measurement_enabled) {
        return -ENODEV;
    }
    int adc_mv;
    BO_TRY(bo_adc_read_mv_filtered(CONFIG_LYFI_MEAS_CURRENT_ADC_CHANNEL, &adc_mv));
    if (adc_mv >= CONFIG_LYFI_MEAS_CURRENT_OFFSET) {
        adc_mv -= CONFIG_LYFI_MEAS_CURRENT_OFFSET;
    }
    *ma = (adc_mv * 1000 + (CONFIG_LYFI_MEAS_CURRENT_FACTOR / 2)) / CONFIG_LYFI_MEAS_CURRENT_FACTOR;
    return 0;
}
#endif

#if CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT
int lyfi_power_read(int32_t* mw)
{
    if (mw == NULL) {
        return -EINVAL;
    }
    if (!s_factory_settings.measurement_enabled) {
        return -ENODEV;
    }

    // TODO Add lock
    uint16_t last_v_adc = 0;
    uint16_t last_c_adc = 0;
    uint16_t v_adc_window[BO_ADC_WINDOW_SIZE];
    uint16_t c_adc_window[BO_ADC_WINDOW_SIZE];
    for (size_t i = 0; i < BO_ADC_WINDOW_SIZE; i++) {
        int adc_v, adc_c;
        BO_TRY(bo_adc_read_mv(CONFIG_BORNEO_MEAS_VOLTAGE_ADC_CHANNEL, &adc_v));
        BO_TRY(bo_adc_read_mv(CONFIG_LYFI_MEAS_CURRENT_ADC_CHANNEL, &adc_c));
        if (adc_v == 0 || adc_v == 4095) {
            adc_v = last_v_adc; // Ignore outliers
        }
        else {
            last_v_adc = adc_v;
        }
        if (adc_c == 0 || adc_c == 4095) {
            adc_c = last_c_adc; // Ignore outliers
        }
        else {
            last_c_adc = adc_c;
        }
        v_adc_window[i] = (uint16_t)adc_v;
        c_adc_window[i] = (uint16_t)adc_c;
    }

    int value_mv;
    int value_ma;

    value_mv = median_filter_u16(v_adc_window, BO_ADC_WINDOW_SIZE);
    value_mv = (value_mv * CONFIG_BORNEO_MEAS_VOLTAGE_FACTOR + 500) / 1000;

    value_ma = median_filter_u16(c_adc_window, BO_ADC_WINDOW_SIZE);
    if (value_ma >= CONFIG_LYFI_MEAS_CURRENT_OFFSET) {
        value_ma -= CONFIG_LYFI_MEAS_CURRENT_OFFSET;
    }
    value_ma = (value_ma * 1000 + (CONFIG_LYFI_MEAS_CURRENT_FACTOR / 2)) / CONFIG_LYFI_MEAS_CURRENT_FACTOR;

    *mw = (value_mv * value_ma + 500) / 1000; // Convert to mW
    return 0;
}
#endif
