
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

#include <drvfx/drvfx.h>

#include "borneo/algo/filters.h"
#include "borneo/common.h"
#include "borneo/system.h"
#include "borneo/devices/adc.h"
#include "borneo/devices/sensor.h"

#define TAG "sensor.voltage"

#if CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT

struct sensor_voltage_data {
    const struct drvfx_device* adc_dev;
    int32_t voltage_mv;
    int32_t filtered_voltage;
};

static int _fetch_sample(const struct drvfx_device* dev)
{
    if (dev == NULL) {
        return -ENODEV;
    }
    if (dev->data == NULL) {
        return -ENOSYS;
    }
    struct sensor_voltage_data* data = (struct sensor_voltage_data*)dev->data;

    int32_t adc_mv;
    BO_TRY(adc_read_mv(data->adc_dev, CONFIG_BORNEO_MEAS_VOLTAGE_ADC_CHANNEL, &adc_mv));
    int32_t raw_mv = (adc_mv * CONFIG_BORNEO_MEAS_VOLTAGE_FACTOR + 500) / 1000;
    data->voltage_mv = ema_filter(raw_mv, &data->filtered_voltage, 1, 10);
    return 0;
}

static int _get_value(const struct drvfx_device* dev, int32_t* value)
{
    if (dev == NULL) {
        return -ENODEV;
    }
    if (dev->data == NULL) {
        return -ENOSYS;
    }
    struct sensor_voltage_data* data = (struct sensor_voltage_data*)dev->data;
    *value = data->voltage_mv;
    return 0;
}

static int sensor_voltage_init(const struct drvfx_device* dev)
{
    if (dev == NULL) {
        return -ENODEV;
    }
    ESP_LOGI(TAG, "Initializing voltage sensor '%s'...", dev->name);

    if (dev->data == NULL) {
        return -ENOSYS;
    }
    struct sensor_voltage_data* data = (struct sensor_voltage_data*)dev->data;

    data->adc_dev = k_device_get_binding("adc");
    if (data->adc_dev == NULL) {
        ESP_LOGE(TAG, "Failed to get device 'adc'");
    }

    BO_TRY(_fetch_sample(dev));

    return 0;
}

const static struct sensor_api s_api = {
    .fetch_sample = &_fetch_sample,
    .get_value = &_get_value,
};

static struct sensor_voltage_data s_data = { 0 };

DRVFX_DEVICE_DEFINE("sensor.voltage", sensor_voltage_init, &s_data, NULL, DRVFX_INIT_POST_KERNEL_DEFAULT_PRIORITY,
                    &s_api);

#endif // CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT