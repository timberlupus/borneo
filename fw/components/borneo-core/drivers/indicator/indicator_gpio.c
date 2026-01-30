#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>
#include <esp_system.h>
#include <esp_log.h>
#include <esp_event.h>
#include <esp_wifi.h>
#include <esp_timer.h>
#include <driver/gpio.h>

#include <drvfx/drvfx.h>
#include <borneo/devices/indicator.h>
#include <borneo/system.h>

#if CONFIG_BORNEO_INDICATOR_ENABLED && CONFIG_BORNEO_INDICATOR_GPIO_ENABLED

#define TAG "indicator"

static void indicator_timer_callback(void* arg);
static void got_ip_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static void lost_ip_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static void _kernel_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static void _system_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);

volatile static int _state = BO_INDICATOR_STATE_NO_CONN;
static esp_timer_handle_t _indicator_timer;
static int _led_state = 0;
static portMUX_TYPE _indicator_lock = portMUX_INITIALIZER_UNLOCKED;

int bo_indicator_init()
{
    ESP_LOGI(TAG, "Indicator initializing...");
    int res = 0;

    uint64_t selected_gpios = 0ULL;

    selected_gpios |= 1ULL << CONFIG_BORNEO_INDICATOR_GPIO;

    gpio_config_t io_conf;
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = selected_gpios;
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 1;
    BO_TRY(gpio_config(&io_conf));

    BO_TRY(gpio_set_level(CONFIG_BORNEO_INDICATOR_GPIO, 0));

    BO_TRY(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &got_ip_event_handler, NULL));
    BO_TRY(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_LOST_IP, &lost_ip_event_handler, NULL));
    BO_TRY(esp_event_handler_register(BO_SYSTEM_EVENTS, ESP_EVENT_ANY_ID, &_system_event_handler, NULL));
    BO_TRY(esp_event_handler_register(KERNEL_EVENTS, ESP_EVENT_ANY_ID, &_kernel_event_handler, NULL));

    const esp_timer_create_args_t timer_args = {
        .callback = &indicator_timer_callback, .arg = NULL, .dispatch_method = ESP_TIMER_TASK, .name = "indicator_timer"
    };
    BO_TRY(esp_timer_create(&timer_args, &_indicator_timer));
    BO_TRY(esp_timer_start_once(_indicator_timer, 1000000)); // Start with 1 second

    return res;
}

static void indicator_timer_callback(void* arg)
{
    uint64_t next_delay_us = 1000000; // Default 1 second

    portENTER_CRITICAL(&_indicator_lock);
    switch (_state) {
    case BO_INDICATOR_STATE_NORMAL: {
        _led_state = 0;
        next_delay_us = 5000000; // 5 seconds
    } break;

    case BO_INDICATOR_STATE_FAULT: {
        _led_state = !_led_state;
        next_delay_us = 200000; // 200 ms
    } break;

    case BO_INDICATOR_STATE_NO_CONN: {
        _led_state = !_led_state;
        next_delay_us = 1000000; // 1 second
    } break;

    default: {
        next_delay_us = 1000000; // 1 second
    }
    }
    portEXIT_CRITICAL(&_indicator_lock);

    BO_MUST(gpio_set_level(CONFIG_BORNEO_INDICATOR_GPIO, _led_state));

    esp_timer_start_once(_indicator_timer, next_delay_us);
}

static void got_ip_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    portENTER_CRITICAL(&_indicator_lock);
    if (_state == BO_INDICATOR_STATE_NO_CONN) {
        _state = BO_INDICATOR_STATE_NORMAL;
    }
    portEXIT_CRITICAL(&_indicator_lock);
}

static void lost_ip_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    portENTER_CRITICAL(&_indicator_lock);
    if (_state == BO_INDICATOR_STATE_NORMAL) {
        _state = BO_INDICATOR_STATE_NO_CONN;
    }
    portEXIT_CRITICAL(&_indicator_lock);
}

static void _kernel_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    portENTER_CRITICAL(&_indicator_lock);
    switch (event_id) {

    case KERNEL_EVENT_ENTERING_SAFE_MODE: {
        _state = BO_INDICATOR_STATE_FAULT;
    } break;

    default:
        break;
    }
    portEXIT_CRITICAL(&_indicator_lock);
}

static void _system_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    portENTER_CRITICAL(&_indicator_lock);
    switch (event_id) {

    case BO_EVENT_FATAL_ERROR: {
        _state = BO_INDICATOR_STATE_FAULT;
    } break;

    case BO_EVENT_SHUTDOWN_FAULT: {
        _state = BO_INDICATOR_STATE_FAULT;
    } break;

    default:
        break;
    }
    portEXIT_CRITICAL(&_indicator_lock);
}

#endif // CONFIG_BORNEO_INDICATOR_ENABLED && CONFIG_BORNEO_INDICATOR_GPIO_ENABLED