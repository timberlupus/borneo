

#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <sys/socket.h>

#include <coap3/coap.h>

#include <borneo/system.h>
#include <borneo/coap.h>
#include <borneo/sntp.h>

#define COAP_TASK_PRIO 5

static int notify_init();
static void notify_task();
static void _system_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);

#define NOTIFY_QUEUE_LENGTH 32
#define NOTIFY_QUEUE_ITEM_SIZE (sizeof(coap_str_const_t))

unsigned int coap_adjust_basetime(coap_context_t* ctx, coap_tick_t now);

static void bo_coap_deinit();
static int register_resource(coap_context_t* ctx, const struct coap_resource_desc* res);
static void _bo_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data);

#define TAG "coap-server"

// Known resources

static coap_context_t* _ctx = NULL;
static coap_address_t _serv_addr;
static coap_endpoint_t* _ep_udp = NULL;
static TaskHandle_t _coap_server_task = NULL;
static volatile bool _should_stop = false;

static StaticQueue_t s_notify_queue_struct;
static uint8_t s_notify_queue_storage[NOTIFY_QUEUE_LENGTH * NOTIFY_QUEUE_ITEM_SIZE];
static QueueHandle_t s_notify_queue = NULL;

static void _coap_server_proc(void* p)
{
    uint32_t wait_ms;
    wait_ms = COAP_RESOURCE_CHECK_TIME * 1000;

    while (!_should_stop) {
        taskYIELD();
        int result = coap_io_process(_ctx, wait_ms);
        if (result < 0) {
            break;
        }
        else if (result != 0 && (uint32_t)result < wait_ms) {
            /* decrement if there is a result wait time returned */
            wait_ms -= result;
        }
        if (result != 0) {
            /* result must have been >= wait_ms, so reset wait_ms */
            wait_ms = COAP_RESOURCE_CHECK_TIME * 1000;
        }
    }
    ESP_LOGI(TAG, "Closing the CoAP sub-system...");
    bo_coap_deinit();
    vTaskDelete(NULL);
}

void _bo_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    // Reset the time in CoAP library
    if (event_base == BO_SNTP_EVENTS && event_id == BO_SNTP_EVENT_SUCCEED) {
        coap_tick_t now;
        coap_clock_init();
        coap_ticks(&now);
        coap_adjust_basetime(_ctx, now);
    }
    else if (event_base == BO_SYSTEM_EVENTS && event_id == BO_EVENT_SHUTDOWN_SCHEDULED) {
        _should_stop = true;
    }
}

static int _coap_init()
{
    int rc = 0;
    ESP_LOGI(TAG, "Initializing CoAP server...");

    coap_set_log_level(CONFIG_COAP_LOG_DEFAULT_LEVEL);

    BO_TRY(esp_event_handler_register(BO_SNTP_EVENTS, ESP_EVENT_ANY_ID, &_bo_event_handler, NULL));

    // Prepare the CoAP server socket
    coap_address_init(&_serv_addr);
    _serv_addr.addr.sin.sin_family = AF_INET;
    _serv_addr.addr.sin.sin_addr.s_addr = INADDR_ANY;
    _serv_addr.addr.sin.sin_port = htons(COAP_DEFAULT_PORT);

    _ctx = coap_new_context(NULL);
    if (_ctx == NULL) {
        ESP_LOGE(TAG, "coap_new_context() failed");
        rc = -ENOMEM;
        goto _EXIT;
    }

    _ep_udp = coap_new_endpoint(_ctx, &_serv_addr, COAP_PROTO_UDP);
    if (_ep_udp == NULL) {
        ESP_LOGE(TAG, "_ep_udp: coap_new_endpoint() failed");
        rc = -ENOMEM;
        goto _DEINIT_AND_EXIT;
    }

    // Register all handlers
    extern const struct coap_resource_desc _coap_resources_start;
    extern const struct coap_resource_desc _coap_resources_end;
    for (const struct coap_resource_desc* it = &_coap_resources_start; it != &_coap_resources_end; ++it) {
        rc = register_resource(_ctx, it);
        if (rc != 0) {
            goto _DEINIT_AND_EXIT;
        }
    }

    ESP_LOGI(TAG, "Starting CoAP server...");
    rc = xTaskCreate(&_coap_server_proc, "coap", 8 * 1024, NULL, COAP_TASK_PRIO, &_coap_server_task);
    if (rc != pdPASS) {
        rc = -ENOMEM;
        goto _DEINIT_AND_EXIT;
    }

    BO_TRY(notify_init());

    ESP_LOGI(TAG, "CoAP module has been initialized successfully.");
    return 0;

_DEINIT_AND_EXIT:
    bo_coap_deinit();
_EXIT:
    return rc;
}

void bo_coap_deinit()
{
    if (_ctx != NULL) {
        coap_free_context(_ctx);
        _ctx = NULL;
        coap_cleanup();
    }
}

static int register_resource(coap_context_t* ctx, const struct coap_resource_desc* res)
{
    if (ctx == NULL || res == NULL) {
        return -EINVAL;
    }
    ESP_LOGI(TAG, "Registering CoAP resource `%s`", res->path.s);
    coap_resource_t* resource = coap_resource_init((coap_str_const_t*)&res->path, COAP_RESOURCE_FLAGS_RELEASE_URI);
    if (resource == NULL) {
        ESP_LOGE(TAG, "coap_resource_init() failed");
        return -EINVAL;
    }

    if (res->get_handler != NULL) {
        coap_register_request_handler(resource, COAP_REQUEST_GET, res->get_handler);
    }
    if (res->post_handler != NULL) {
        coap_register_request_handler(resource, COAP_REQUEST_POST, res->post_handler);
    }
    if (res->put_handler != NULL) {
        coap_register_request_handler(resource, COAP_REQUEST_PUT, res->put_handler);
    }
    if (res->delete_handler != NULL) {
        coap_register_request_handler(resource, COAP_REQUEST_DELETE, res->delete_handler);
    }
    coap_resource_set_get_observable(resource, res->is_observable ? 1 : 0);
    coap_add_resource(ctx, resource);
    return 0;
}

int bo_coap_notify_resource_changed(const coap_str_const_t* resource_uri)
{
    BaseType_t rc = xQueueSendToBackFromISR(s_notify_queue, resource_uri, NULL);
    if (rc != pdTRUE) {
        return -EIO;
    }
    return 0;
}

int notify_init()
{
    s_notify_queue = xQueueCreateStatic(NOTIFY_QUEUE_LENGTH, NOTIFY_QUEUE_ITEM_SIZE, s_notify_queue_storage,
                                        &s_notify_queue_struct);
    if (!s_notify_queue) {
        return -ENOMEM;
    }

    BO_TRY(esp_event_handler_register(BO_SYSTEM_EVENTS, ESP_EVENT_ANY_ID, &_system_event_handler, NULL));

    BaseType_t rc = xTaskCreate(&notify_task, "coap.notify", 1024, NULL, tskIDLE_PRIORITY + 1, NULL);
    if (rc != pdPASS) {
        return -ENOMEM;
    }

    return 0;
}

void notify_task()
{
    static const coap_str_const_t BO_COAP_URI_HEARTBEAT = {
        .s = (const uint8_t*)BO_COAP_PATH_HEARTBEAT,
        .length = sizeof(BO_COAP_PATH_HEARTBEAT) - 1,
    };
    coap_resource_t* res_heartbeat = coap_get_resource_from_uri_path(_ctx, (coap_str_const_t*)&BO_COAP_URI_HEARTBEAT);

    for (;;) {
        coap_str_const_t path;
        if (xQueueReceive(s_notify_queue, &path, pdMS_TO_TICKS(BO_COAP_HEARTBEAT_INTERVAL_MS)) == pdTRUE) {
            coap_resource_t* res = coap_get_resource_from_uri_path(_ctx, &path);
            if (res) {
                coap_resource_notify_observers(res, NULL);
            }
        }
        else {
            if (res_heartbeat) {
                coap_resource_notify_observers(res_heartbeat, NULL);
            }
        }
    }
}

void _system_event_handler(void* arg, esp_event_base_t event_base, int32_t event_id, void* event_data)
{
    switch (event_id) {

    case BO_EVENT_POWER_ON:
    case BO_EVENT_SHUTDOWN_SCHEDULED:
    case BO_EVENT_SHUTDOWN_FAULT: {
        coap_str_const_t uri = { .s = (const uint8_t*)BO_COAP_PATH_POWER, .length = sizeof(BO_COAP_PATH_POWER) - 1 };
        BO_MUST(bo_coap_notify_resource_changed(&uri));
    } break;

    default:
        break;
    }
}

DRVFX_SYS_INIT(_coap_init, APPLICATION, DRVFX_INIT_APP_DEFAULT_PRIORITY);