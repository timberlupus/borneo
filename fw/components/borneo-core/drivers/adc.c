#include <errno.h>

#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>
#include <freertos/semphr.h> // 添加互斥锁头文件
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

#define TAG "adc"

#if CONFIG_BORNEO_ADC_ENABLED

#define AVAILABLE_ADC_UNIT ADC_UNIT_1

struct adc_data {
    adc_oneshot_unit_handle_t handle;
    adc_cali_handle_t cali;
    SemaphoreHandle_t mutex; // 添加互斥锁
};

/*
int bo_adc_channel_config(adc_channel_t channel)
{
    adc_oneshot_chan_cfg_t adc_config = {
        .bitwidth = ADC_BITWIDTH_12,
        .atten = ADC_ATTEN_DB_12,
    };
    BO_TRY(adc_oneshot_config_channel(s_adc_handle, channel, &adc_config));
    return 0;
}

int bo_adc_read_mv_filtered(adc_channel_t channel, int* value_mv)
{
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
*/

static int _adc_cali(adc_cali_handle_t* out_handle)
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
            .bitwidth = ADC_BITWIDTH_12,
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
            .bitwidth = ADC_BITWIDTH_12,
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

static int _read_mv(const struct drvfx_device* dev, adc_channel_t channel, int32_t* mv)
{
    struct adc_data* data = (struct adc_data*)dev->data;
    xSemaphoreTake(data->mutex, portMAX_DELAY);
    int rc = adc_oneshot_get_calibrated_result(data->handle, data->cali, channel, (int*)mv);
    xSemaphoreGive(data->mutex);
    return rc;
}

static int adc_init(const struct drvfx_device* dev)
{
    ESP_LOGI(TAG, "Initializing ADC...");
    struct adc_data* data = (struct adc_data*)dev->data;

    data->mutex = xSemaphoreCreateMutex();
    if (data->mutex == NULL) {
        ESP_LOGE(TAG, "Failed to create ADC mutex");
        return -1;
    }

    adc_oneshot_unit_init_cfg_t unit_config = { 0 };
    unit_config.unit_id = AVAILABLE_ADC_UNIT;
    BO_TRY(adc_oneshot_new_unit(&unit_config, &data->handle));
    ESP_LOGI(TAG, "Calibrating ADC...");
    BO_TRY(_adc_cali(&data->cali));

    adc_oneshot_chan_cfg_t adc_config = {
        .bitwidth = ADC_BITWIDTH_12,
        .atten = ADC_ATTEN_DB_12,
    };

#if CONFIG_BORNEO_ADC_CH0_ENABLED
    BO_TRY(adc_oneshot_config_channel(data->handle, ADC_CHANNEL_0, &adc_config));
#endif

#if CONFIG_BORNEO_ADC_CH1_ENABLED
    BO_TRY(adc_oneshot_config_channel(data->handle, ADC_CHANNEL_1, &adc_config));
#endif

#if CONFIG_BORNEO_ADC_CH2_ENABLED
    BO_TRY(adc_oneshot_config_channel(data->handle, ADC_CHANNEL_2, &adc_config));
#endif

#if CONFIG_BORNEO_ADC_CH3_ENABLED
    BO_TRY(adc_oneshot_config_channel(data->handle, ADC_CHANNEL_3, &adc_config));
#endif

#if CONFIG_BORNEO_ADC_CH4_ENABLED
    BO_TRY(adc_oneshot_config_channel(data->handle, ADC_CHANNEL_4, &adc_config));
#endif

#if CONFIG_BORNEO_ADC_CH5_ENABLED
    BO_TRY(adc_oneshot_config_channel(data->handle, ADC_CHANNEL_5, &adc_config));
#endif

#if CONFIG_BORNEO_ADC_CH6_ENABLED
    BO_TRY(adc_oneshot_config_channel(data->handle, ADC_CHANNEL_6, &adc_config));
#endif

#if CONFIG_BORNEO_ADC_CH7_ENABLED
    BO_TRY(adc_oneshot_config_channel(data->handle, ADC_CHANNEL_7, &adc_config));
#endif

    return 0;
}

const static struct adc_driver_api s_api = {
    .read_mv = &_read_mv,
};

static struct adc_data s_data = { 0 };

DRVFX_DEVICE_DEFINE("adc", adc_init, &s_data, NULL, DRVFX_INIT_POST_KERNEL_HIGH_PRIORITY, &s_api);

#endif // CONFIG_BORNEO_ADC_ENABLED