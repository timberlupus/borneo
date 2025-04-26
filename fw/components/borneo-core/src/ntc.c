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

#include <borneo/system.h>
#include <borneo/algo/filters.h>
#include <borneo/devices/adc.h>
#include <borneo/ntc.h>

#if CONFIG_BORNEO_NTC_ENABLED

#define TAG "NTC"

static int8_t ntc_table_lookup(int r);

#define NTC_SAMPLING_TIMES 8
#define NTC_TEMP_BUF_SIZE 16
#define NTC_ADC_MAX_VALUE 1023
#define ADC_WINDOW_SIZE 5

// clang-format off

// 0~105 ℃

#if CONFIG_BORNEO_NTC_PU_4K7
    // VRef=2.5V, 4.7kΩ Pull-up
const uint16_t NTC_MAPPING_TABLE[] = {
    2193, 2179, 2164, 2149, 2133, 2116, 2100, 2082, 2064, 2046,
    2028, 2009, 1989, 1969, 1949, 1928, 1907, 1885, 1863, 1841,
    1818, 1795, 1772, 1749, 1725, 1701, 1676, 1652, 1627, 1602,
    1578, 1552, 1527, 1502, 1477, 1451, 1426, 1401, 1376, 1350,
    1325, 1300, 1275, 1250, 1226, 1201, 1177, 1153, 1129, 1106,
    1082, 1059, 1036, 1014, 992, 970, 948, 927, 906, 885,
    865, 845, 825, 806, 787, 769, 750, 733, 715, 698,
    681, 665, 649, 633, 617, 602, 588, 573, 559, 545,
    532, 519, 506, 494, 481, 469, 458, 447, 436, 425,
    414, 404, 394, 384, 375, 366, 357, 348, 339, 331,
    323, 315, 308, 300, 293, 286,
};
#elif CONFIG_BORNEO_NTC_PU_10K
    // VRef=3.3V, 10kΩ Pull-up
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
    216, 210, 205, 199, 194, 189,
};
#else
#error "Unknown NTC pull-up resistor"
#endif

// clang-format on

enum {
    NTC_MAPPING_TABLE_SIZE = sizeof(NTC_MAPPING_TABLE) / sizeof(NTC_MAPPING_TABLE[0]),
};

int ntc_init()
{
    ESP_LOGI(TAG, "Initializing NTC...");

    BO_TRY(bo_adc_channel_config(CONFIG_BORNEO_NTC_ADC_CHANNEL));
    return 0;
}

/** @brief Read the temperature
 *  @retval Temperature in celsius
 */
int ntc_read_temp(int* temp)
{
    int adc_mv;
    BO_TRY(bo_adc_read_mv_filtered(CONFIG_BORNEO_NTC_ADC_CHANNEL, &adc_mv));
    if (adc_mv == 0 || adc_mv == 4095) {
        ESP_LOGE(TAG, "No NTC connected! sample_avg=%d", adc_mv);
        return -EIO;
    }

    int value = ntc_table_lookup(adc_mv);
    if (value == NTC_BAD_TEMPERATURE) {
        ESP_LOGE(TAG, "Bad temperature!");
        return -EIO;
    }
    *temp = value;
    return 0;
}

static int8_t ntc_table_lookup(int value)
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

#endif // CONFIG_BORNEO_NTC_ENABLED