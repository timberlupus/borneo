#include <freertos/FreeRTOS.h>
#include <freertos/task.h>
#include <freertos/event_groups.h>
#include <esp_system.h>
#include <esp_log.h>
#include <esp_event.h>
#include <esp_wifi.h>
#include <driver/gpio.h>

#include <borneo/devices/indicator.h>
#include <borneo/system.h>

#define TAG "indicator"
#define TASK_STACK_SIZE 512

static void indicator_task();
static void got_ip_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static void lost_ip_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);
static void _system_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);

volatile static int _state = BO_INDICATOR_STATE_NO_CONN;

static StackType_t _task_stack[TASK_STACK_SIZE];
static StaticTask_t _task_tcb;

int bo_indicator_init()
{
    ESP_LOGI(TAG, "Indicator initializing...");
    int res = 0;

    uint64_t selected_gpios = 0ULL;

#if CONFIG_BORNEO_INDICATOR_ENABLED
    selected_gpios |= 1ULL << CONFIG_BORNEO_INDICATOR_GPIO;
#endif // CONFIG_BORNEO_INDICATOR_ENABLED

    gpio_config_t io_conf;
    io_conf.intr_type = GPIO_INTR_DISABLE;
    io_conf.mode = GPIO_MODE_OUTPUT;
    io_conf.pin_bit_mask = selected_gpios;
    io_conf.pull_down_en = 0;
    io_conf.pull_up_en = 1;
    BO_TRY(gpio_config(&io_conf));

#if CONFIG_BORNEO_INDICATOR__ENABLED
    BO_TRY(gpio_set_level(CONFIG_BORNEO_INDICATOR_GPIO, 0));
#endif

    BO_TRY(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_GOT_IP, &got_ip_event_handler, NULL));
    BO_TRY(esp_event_handler_register(IP_EVENT, IP_EVENT_STA_LOST_IP, &lost_ip_event_handler, NULL));
    BO_TRY(esp_event_handler_register(BO_SYSTEM_EVENTS, BO_EVENT_FATAL_ERROR, &_system_event_handler, NULL));

    xTaskCreateStatic(indicator_task, "indicator_task", TASK_STACK_SIZE, NULL, tskIDLE_PRIORITY, _task_stack,
                      &_task_tcb);
    return res;
}

void indicator_task(void* args)
{
    uint32_t x = 0;
    int delay = pdMS_TO_TICKS(1000);
    while (1) {

        switch (_state) {
        case BO_INDICATOR_STATE_NORMAL: {
            delay = pdMS_TO_TICKS(5000);
            x = 0;
        } break;

        case BO_INDICATOR_STATE_FAULT: {
            x = !x;
            delay = pdMS_TO_TICKS(200);
        } break;

        case BO_INDICATOR_STATE_NO_CONN: {
            x = !x;
            delay = pdMS_TO_TICKS(1000);
        } break;

        default: {
            delay = pdMS_TO_TICKS(1000);
        }
        }

        BO_MUST(gpio_set_level(CONFIG_BORNEO_INDICATOR_GPIO, x));

        vTaskDelay(delay);
    }
}

static void got_ip_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    if (_state == BO_INDICATOR_STATE_NO_CONN) {
        _state = BO_INDICATOR_STATE_NORMAL;
    }
}

static void lost_ip_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    if (_state == BO_INDICATOR_STATE_NORMAL) {
        _state = BO_INDICATOR_STATE_NO_CONN;
    }
}

static void _system_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
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
}