#include <string.h>
#include <sys/time.h>

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
#include <esp_adc/adc_cali.h>
#include <esp_adc/adc_cali_scheme.h>

#include <borneo/system.h>
#include <borneo/ntc.h>

#if CONFIG_BORNEO_NTC_ENABLED

#define TAG "NTC"

static int8_t ntc_table_lookup(int r);
static int ntc_adc_cali(adc_unit_t unit, adc_atten_t atten, adc_cali_handle_t* out_handle);

#define NTC_SAMPLING_TIMES 8
#define NTC_TEMP_BUF_SIZE 16
#define NTC_ADC_MAX_VALUE 1023

// 0~105 度的 ADC 电压（mV）温度映射表
// clang-format off
// 0~150 度
const uint16_t NTC_MAPPING_TABLE[] = {
    2549, 2518, 2486, 2453, 2420, 2386, 2352, 2318, 2283, 2247,
    2211, 2175, 2138, 2101, 2064, 2027, 1990, 1952, 1915, 1877,
    1840, 1802, 1765, 1727, 1690, 1654, 1617, 1581, 1545, 1509,
    1474, 1439, 1404, 1370, 1337, 1303, 1271, 1239, 1207, 1176,
    1146, 1116, 1087, 1058, 1030, 1002, 975, 949, 923, 898,
    873, 849, 826, 803, 781, 759, 738, 717, 697, 677,
    658, 640, 622, 604, 587, 571, 555, 539, 524, 509,
    495, 481, 467, 454, 442, 429, 417, 406, 394, 383,
    373, 362, 352, 343, 333, 324, 315, 307, 298, 290,
    282, 275, 267, 260, 253, 246, 240, 234, 227, 221,
    216, 210, 205, 199, 194, 189
};
// clang-format on

enum {
    NTC_MAPPING_TABLE_SIZE = sizeof(NTC_MAPPING_TABLE) / sizeof(NTC_MAPPING_TABLE[0]),
};

// static esp_adc_cal_characteristics_t* adc_chars;
static volatile int _last_temp = NTC_BAD_TEMPERATURE;
static adc_oneshot_unit_handle_t _adc_handle = NULL;
static adc_cali_handle_t _adc_cali_handle;

int ntc_init()
{
    ESP_LOGI(TAG, "Initializing NTC ADC...");

    adc_oneshot_unit_init_cfg_t init_config1 = { 0 };
    init_config1.unit_id = CONFIG_BORNEO_NTC_ADC_UNIT;
    BO_TRY(adc_oneshot_new_unit(&init_config1, &_adc_handle));

    if (_adc_handle == NULL) {
        ESP_LOGE(TAG, "Failed to call `adc_oneshot_new_unit()`");
        return ESP_ERR_INVALID_ARG;
    }

    adc_oneshot_chan_cfg_t adc_config = {
        .bitwidth = ADC_BITWIDTH_12,
        .atten = ADC_ATTEN_DB_12,
    };
    BO_TRY(adc_oneshot_config_channel(_adc_handle, CONFIG_BORNEO_NTC_ADC_CHANNEL, &adc_config));

    BO_TRY(ntc_adc_cali(CONFIG_BORNEO_NTC_ADC_UNIT, ADC_ATTEN_DB_12, &_adc_cali_handle));

    // 初始化 NTC
    return 0;
}

/** @brief 读取温度
 *  @retval 温度信息
 */
int ntc_read_temp(int* temp)
{
    int adc_value = 0;

    esp_err_t error = adc_oneshot_read(_adc_handle, CONFIG_BORNEO_NTC_ADC_CHANNEL, &adc_value);
    if (error) {
        *temp = _last_temp;
        return NTC_BAD_TEMPERATURE;
    }

    if (adc_value == 0 || adc_value == 4095) {
        ESP_LOGE(TAG, "No NTC connected! sample_avg=%d", adc_value);
        return -EIO;
    }
    // uint32_t adc_mv = esp_adc_cal_raw_to_voltage(sample_avg, &_adc_chars);
    int adc_mv;
    error = adc_cali_raw_to_voltage(_adc_cali_handle, adc_value, &adc_mv);
    if (error != ESP_OK) {
        ESP_LOGE(TAG, "Failed to convert ADC value!");
        return error;
    }
    int value = ntc_table_lookup(adc_mv);
    if (value == NTC_BAD_TEMPERATURE) {
        ESP_LOGE(TAG, "Bad temperature!");
        return -EIO;
    }
    *temp = value;
    _last_temp = value;
    return 0;
}

/** @brief 查找 NTC 电阻到温度的映射表
 *
 */
static int8_t ntc_table_lookup(int value) // 表中数据从大到小
{

    int left = 0;
    int right = NTC_MAPPING_TABLE_SIZE - 1;
    int closest_index = NTC_BAD_TEMPERATURE;
    int min_diff = abs(NTC_MAPPING_TABLE[0] - value);

    while (left <= right) {
        int mid = left + (right - left) / 2;
        int difference = abs(NTC_MAPPING_TABLE[mid] - value);

        if (difference < min_diff) {
            min_diff = difference;
            closest_index = mid;
        }

        if (NTC_MAPPING_TABLE[mid] == value) {
            return mid;
        }
        else if (NTC_MAPPING_TABLE[mid] > value) {
            left = mid + 1;
        }
        else {
            right = mid - 1;
        }
    }

    return closest_index;
}

static int ntc_adc_cali(adc_unit_t unit, adc_atten_t atten, adc_cali_handle_t* out_handle)
{
    adc_cali_handle_t handle = NULL;
    esp_err_t ret = ESP_FAIL;
    bool calibrated = false;

#if ADC_CALI_SCHEME_CURVE_FITTING_SUPPORTED
    if (!calibrated) {
        ESP_LOGI(TAG, "calibration scheme version is %s", "Curve Fitting");
        adc_cali_curve_fitting_config_t cali_config = {
            .unit_id = unit,
            .atten = atten,
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
            .unit_id = unit,
            .atten = atten,
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

#endif // CONFIG_BORNEO_NTC_ENABLED