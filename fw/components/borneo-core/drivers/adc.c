#include <errno.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>
#include <esp_system.h>
#include <esp_log.h>
#include <esp_event.h>
#include <esp_wifi.h>
#include <driver/gpio.h>

#include <esp_adc/adc_oneshot.h>
#include <esp_adc/adc_cali.h>
#include <esp_adc/adc_cali_scheme.h>

#include <borneo/system.h>
#include <borneo/algo/filters.h>
#include <borneo/devices/adc.h>

static int bo_adc_cali(adc_cali_handle_t* out_handle);

#define TAG "adc"

#if CONFIG_IDF_TARGET_ESP32C3
#define AVAILABLE_ADC_UNIT ADC_UNIT_1
#else
#error ("Not implemented!")
#endif

static adc_oneshot_unit_handle_t s_adc_handle = NULL;
static adc_cali_handle_t s_adc_cali_handle = NULL;

adc_cali_handle_t bo_adc_get_cali()
{
    //
    return s_adc_cali_handle;
}

int bo_adc_channel_config(adc_channel_t channel)
{
    adc_oneshot_chan_cfg_t adc_config = {
        .bitwidth = ADC_BITWIDTH_12,
        .atten = ADC_ATTEN_DB_12,
    };
    return adc_oneshot_config_channel(s_adc_handle, channel, &adc_config);
}

int bo_adc_read_mv(adc_channel_t channel, int* value_mv)
{
    return adc_oneshot_get_calibrated_result(s_adc_handle, s_adc_cali_handle, channel, value_mv);
}

int bo_adc_read_mv_filtered(adc_channel_t channel, int* value_mv)
{
    // TODO Add lock
    uint16_t adc_window[BO_ADC_WINDOW_SIZE];
    int last_adc_mv = 0;
    for (size_t i = 0; i < BO_ADC_WINDOW_SIZE; i++) {
        int adc_mv;
        BO_TRY(bo_adc_read_mv(channel, &adc_mv));
        if (adc_mv == 0 || adc_mv == 4095) {
            adc_mv = last_adc_mv; // Ignore outliers
        }
        else {
            last_adc_mv = adc_mv;
        }
        adc_window[i] = (uint16_t)adc_mv;
    }
    *value_mv = median_filter_u16(adc_window, BO_ADC_WINDOW_SIZE);

    return 0;
}

int bo_adc_cali(adc_cali_handle_t* out_handle)
{
    adc_cali_handle_t handle = NULL;
    esp_err_t ret = ESP_FAIL;
    bool calibrated = false;

#if ADC_CALI_SCHEME_CURVE_FITTING_SUPPORTED
    if (!calibrated) {
        ESP_LOGI(TAG, "calibration scheme version is %s", "Curve Fitting");
        adc_cali_curve_fitting_config_t cali_config = {
            .unit_id = AVAILABLE_ADC_UNIT,
            .atten = ADC_ATTEN_DB_12,
            .bitwidth = ADC_BITWIDTH_DEFAULT,
        };
        ret = adc_cali_create_scheme_curve_fitting(&cali_config, &handle);
        if (ret == ESP_OK) {
            calibrated = true;
        }
    }
#endif

#if ADC_CALI_SCHEME_LINE_FITTING_SUPPORTED
    if (!calibrated) {
        ESP_LOGI(TAG, "Calibration scheme version is %s", "Line Fitting");
        adc_cali_line_fitting_config_t cali_config = {
            .unit_id = AVAILABLE_ADC_UNIT,
            .atten = ADC_ATTEN_DB_12,
            .bitwidth = ADC_BITWIDTH_DEFAULT,
        };
        ret = adc_cali_create_scheme_line_fitting(&cali_config, &handle);
        if (ret == ESP_OK) {
            calibrated = true;
        }
    }
#endif

    *out_handle = handle;
    if (ret == ESP_OK) {
        ESP_LOGI(TAG, "Calibration Success");
    }
    else if (ret == ESP_ERR_NOT_SUPPORTED || !calibrated) {
        ESP_LOGW(TAG, "eFuse not burnt, skip software calibration");
    }
    else {
        ESP_LOGE(TAG, "Invalid arg or no memory");
    }

    return ret;
}

static int adc_init()
{

    //
    ESP_LOGI(TAG, "Initializing ADC...");

    adc_oneshot_unit_init_cfg_t unit_config = { 0 };
    unit_config.unit_id = 0;
    BO_TRY(adc_oneshot_new_unit(&unit_config, &s_adc_handle));

    ESP_LOGI(TAG, "Calibrating ADC...");
    BO_TRY(bo_adc_cali(&s_adc_cali_handle));

    return 0;
}

#if CONFIG_BORNEO_ADC_ENABLED

DRVFX_SYS_INIT(adc_init, POST_KERNEL, DRVFX_INIT_KERNEL_DEFAULT_PRIORITY);

#endif // CONFIG_BORNEO_ADC_ENABLED