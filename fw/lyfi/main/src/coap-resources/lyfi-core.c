#include <stdint.h>
#include <stdbool.h>
#include <math.h>

#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <sys/socket.h>

#include "coap3/coap.h"
#include <cbor.h>

#include <borneo/system.h>
#include <borneo/coap.h>
#include <borneo/rtc.h>

#include "../led.h"
#include "../fan.h"
#include "cbor.h"

#define TAG "lyfi-coap"

static int _encode_channel_info_entry(CborEncoder* parent, const char* name, const char* color,
                                      uint32_t brightness_percent, uint32_t power);
static int _encode_channel_info_array(CborEncoder* parent);

extern struct led_status _led;

static void coap_hnd_color_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                               const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    uint8_t buf[128];

    led_color_t color;
    BO_COAP_VERIFY(led_get_color(color));

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    BO_COAP_VERIFY(cbor_encode_color(&encoder, color));

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_color_put(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                               const coap_string_t* query, coap_pdu_t* response)
{
    size_t data_size;
    const uint8_t* data;

    coap_resource_notify_observers(resource, NULL);

    /*
     coap_get_data() sets size to 0 on error
    */
    led_color_t color;

    coap_get_data(request, &data_size, &data);

    CborParser parser;
    CborValue value;
    BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &value));
    BO_COAP_VERIFY(cbor_value_get_led_color(&value, color));
    BO_COAP_VERIFY(led_set_color(color));

    coap_pdu_set_code(response, BO_COAP_CODE_204_CHANGED);
}

static void coap_hnd_schedule_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                  const coap_string_t* query, coap_pdu_t* response)
{
    size_t encoded_size = 0;
    const struct led_scheduler* sch = led_get_schedule();
    uint8_t buf[1024];

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    CborEncoder root_array;
    BO_COAP_VERIFY(cbor_encoder_create_array(&encoder, &root_array, sch->item_count));
    for (size_t i = 0; i < sch->item_count; i++) {
        const struct led_scheduler_item* sch_item = &sch->items[i];
        BO_COAP_VERIFY(cbor_encode_led_sch_item(&root_array, sch_item));
    }
    BO_COAP_VERIFY(cbor_encoder_close_container(&encoder, &root_array));

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_schedule_put(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                  const coap_string_t* query, coap_pdu_t* response)
{
    size_t data_size;
    const uint8_t* data;

    coap_resource_notify_observers(resource, NULL);

    struct led_scheduler scheduler;
    memset(&scheduler, 0, sizeof(scheduler));

    coap_get_data(request, &data_size, &data);

    // [[hour, minute, []], ...]
    size_t item_count = 0;

    CborParser parser;
    CborValue it;
    BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &it));

    CborValue root_array;
    BO_COAP_VERIFY(cbor_value_enter_container(&it, &root_array));
    BO_COAP_VERIFY(cbor_value_get_array_length(&it, &item_count));
    scheduler.item_count = item_count;
    ESP_LOGI(TAG, "received schedule, item count: %u", item_count);
    for (size_t i = 0; i < item_count; i++) {
        CborValue item_array;
        BO_COAP_VERIFY(cbor_value_enter_container(&root_array, &item_array));
        struct led_scheduler_item* sch_item = &scheduler.items[i];

        int instant;
        BO_COAP_VERIFY(cbor_value_get_int(&item_array, &instant));
        sch_item->instant = (uint32_t)instant;
        BO_COAP_VERIFY(cbor_value_advance(&item_array));

        BO_COAP_VERIFY(cbor_value_get_led_color(&item_array, sch_item->color));
        BO_COAP_VERIFY(cbor_value_leave_container(&root_array, &item_array));
    }
    BO_COAP_VERIFY(cbor_value_leave_container(&it, &root_array));

    BO_COAP_VERIFY(led_set_schedule(scheduler.items, scheduler.item_count));

    coap_pdu_set_code(response, BO_COAP_CODE_204_CHANGED);
}

static int _encode_channel_info_entry(CborEncoder* parent, const char* name, const char* color,
                                      uint32_t brightness_percent, uint32_t power)
{
    CborEncoder ch_map;
    BO_TRY(cbor_encoder_create_map(parent, &ch_map, CborIndefiniteLength));

    BO_TRY(cbor_encode_text_stringz(&ch_map, "name"));
    BO_TRY(cbor_encode_text_stringz(&ch_map, name));

    BO_TRY(cbor_encode_text_stringz(&ch_map, "color"));
    BO_TRY(cbor_encode_text_stringz(&ch_map, color));

    BO_TRY(cbor_encode_text_stringz(&ch_map, "brightnessPercent"));
    BO_TRY(cbor_encode_uint(&ch_map, brightness_percent));

    BO_TRY(cbor_encoder_close_container(parent, &ch_map));

    return 0;
}

static int _encode_channel_info_array(CborEncoder* parent)
{
    CborEncoder channels_array;
    BO_TRY(cbor_encoder_create_array(parent, &channels_array, CONFIG_LYFI_LED_CHANNEL_COUNT));

    // Channel 0
#if CONFIG_LYFI_LED_CH0_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH0_NAME, CONFIG_LYFI_LED_CH0_COLOR,
                                      CONFIG_LYFI_LED_CH0_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH0_POWER));
#endif

    // Channel 1
#if CONFIG_LYFI_LED_CH1_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH1_NAME, CONFIG_LYFI_LED_CH1_COLOR,
                                      CONFIG_LYFI_LED_CH1_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH1_POWER));
#endif

    // Channel 2
#if CONFIG_LYFI_LED_CH2_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH2_NAME, CONFIG_LYFI_LED_CH2_COLOR,
                                      CONFIG_LYFI_LED_CH2_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH2_POWER));
#endif

    // Channel 3
#if CONFIG_LYFI_LED_CH3_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH3_NAME, CONFIG_LYFI_LED_CH3_COLOR,
                                      CONFIG_LYFI_LED_CH3_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH3_POWER));
#endif

    // Channel 4
#if CONFIG_LYFI_LED_CH4_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH4_NAME, CONFIG_LYFI_LED_CH4_COLOR,
                                      CONFIG_LYFI_LED_CH4_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH4_POWER));
#endif

    // Channel 5
#if CONFIG_LYFI_LED_CH5_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH5_NAME, CONFIG_LYFI_LED_CH5_COLOR,
                                      CONFIG_LYFI_LED_CH5_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH5_POWER));
#endif

    // Channel 6
#if CONFIG_LYFI_LED_CH6_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH6_NAME, CONFIG_LYFI_LED_CH6_COLOR,
                                      CONFIG_LYFI_LED_CH6_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH6_POWER));
#endif

    // Channel 7
#if CONFIG_LYFI_LED_CH7_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH7_NAME, CONFIG_LYFI_LED_CH7_COLOR,
                                      CONFIG_LYFI_LED_CH7_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH7_POWER));
#endif

    // Channel 8
#if CONFIG_LYFI_LED_CH8_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH8_NAME, CONFIG_LYFI_LED_CH8_COLOR,
                                      CONFIG_LYFI_LED_CH0_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH0_POWER));
#endif

    // Channel 9
#if CONFIG_LYFI_LED_CH9_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH9_NAME, CONFIG_LYFI_LED_CH9_COLOR,
                                      CONFIG_LYFI_LED_CH8_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH8_POWER));
#endif

    // Channel 10
#if CONFIG_LYFI_LED_CH10_ENABLED
    BO_TRY(_encode_channel_info_entry(&channels_array, CONFIG_LYFI_LED_CH10_NAME, CONFIG_LYFI_LED_CH10_COLOR,
                                      CONFIG_LYFI_LED_CH9_BRIGHTNESS_PERCENT, CONFIG_LYFI_LED_CH9_POWER));
#endif

    BO_TRY(cbor_encoder_close_container(parent, &channels_array));

    return 0;
}

static void coap_hnd_info_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                              const coap_string_t* query, coap_pdu_t* response)
{
    size_t encoded_size = 0;
    uint8_t buf[1024];

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

    CborEncoder root_map;
    BO_COAP_VERIFY(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength));
    {
        BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "isStandaloneController"));
#if CONFIG_LYFI_STANDALONE_CONTROLLER
        BO_COAP_VERIFY(cbor_encode_boolean(&root_map, true));
#else
        BO_COAP_VERIFY(cbor_encode_boolean(&root_map, false));
#endif // CONFIG_LYFI_STANDALONE_CONTROLLER
    }

#if CONFIG_LYFI_LED_NOMINAL_POWER
    {
        BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "nominalPower"));
        BO_COAP_VERIFY(cbor_encode_uint(&root_map, CONFIG_LYFI_LED_NOMINAL_POWER));
    }
#endif // CONFIG_LYFI_LED_NOMINAL_POWER

    {
        BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "channelCount"));
        BO_COAP_VERIFY(cbor_encode_uint(&root_map, CONFIG_LYFI_LED_CHANNEL_COUNT));
    }

    {
        BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "channels"));
        BO_COAP_VERIFY(_encode_channel_info_array(&root_map));
    }

    BO_COAP_TRY_ENCODE_CBOR(cbor_encoder_close_container(&encoder, &root_map));

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_status_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                const coap_string_t* query, coap_pdu_t* response)
{
    size_t encoded_size = 0;
    uint8_t buf[1024];

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

    CborEncoder root_map;
    BO_COAP_VERIFY(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength));

    const struct led_user_settings* led_settings = led_get_settings();
    const struct led_status* led_status = led_get_status();

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "state"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, led_status->state));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "mode"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, led_settings->mode));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "unscheduled"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_boolean(&root_map, led_status->state == LED_STATE_TEMPORARY));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "tempRemain"));
        int32_t remaining = led_get_temporary_remaining();
        if (remaining < 0) {
            remaining = 0;
        }
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, (uint32_t)remaining));
    }

    {
        const struct fan_status fs = fan_get_status();
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "fanPower"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&root_map, fs.power));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "currentColor"));
        led_color_t color;
        BO_COAP_VERIFY(led_get_color(color));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_color(&root_map, color));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "manualColor"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_color(&root_map, led_get_settings()->manual_color));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "sunColor"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_color(&root_map, led_get_settings()->sun_color));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "acclimationEnabled"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_boolean(&root_map, led_acclimation_is_enabled()));
    }

    {
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_text_stringz(&root_map, "acclimationActivated"));
        BO_COAP_TRY_ENCODE_CBOR(cbor_encode_boolean(&root_map, led_acclimation_is_activated()));
    }

    BO_COAP_TRY_ENCODE_CBOR(cbor_encoder_close_container(&encoder, &root_map));

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_state_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                               const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    const struct led_status* status = led_get_status();

    uint8_t buf[128];

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&encoder, status->state));
    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
}

static void coap_hnd_state_put(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                               const coap_string_t* query, coap_pdu_t* response)
{
    coap_resource_notify_observers(resource, NULL);

    size_t data_size;
    const uint8_t* data;
    coap_get_data(request, &data_size, &data);

    CborParser parser;
    CborValue value;
    BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &value));
    int state;
    BO_COAP_VERIFY(cbor_value_get_int_checked(&value, &state));

    BO_COAP_VERIFY(led_switch_state((uint8_t)state));

    coap_pdu_set_code(response, BO_COAP_CODE_204_CHANGED);
}

static void coap_hnd_correction_method_get(coap_resource_t* resource, coap_session_t* session,
                                           const coap_pdu_t* request, const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    const struct led_user_settings* settings = led_get_settings();

    uint8_t buf[128];

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&encoder, settings->correction_method));
    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
}

static void coap_hnd_correction_method_put(coap_resource_t* resource, coap_session_t* session,
                                           const coap_pdu_t* request, const coap_string_t* query, coap_pdu_t* response)
{
    coap_resource_notify_observers(resource, NULL);

    size_t data_size;
    const uint8_t* data;
    coap_get_data(request, &data_size, &data);

    CborParser parser;
    CborValue value;
    // FIXME TODO Check state range
    BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &value));
    int correction_method;
    BO_COAP_VERIFY(cbor_value_get_int_checked(&value, &correction_method));

    BO_COAP_VERIFY(led_set_correction_method((uint8_t)correction_method));

    coap_pdu_set_code(response, BO_COAP_CODE_204_CHANGED);
}

static void coap_hnd_mode_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                              const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    const struct led_user_settings* settings = led_get_settings();

    uint8_t buf[128];

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&encoder, settings->mode));
    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
}

static void coap_hnd_mode_put(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                              const coap_string_t* query, coap_pdu_t* response)
{
    coap_resource_notify_observers(resource, NULL);

    size_t data_size;
    const uint8_t* data;
    coap_get_data(request, &data_size, &data);

    CborParser parser;
    CborValue value;
    BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &value));
    uint64_t mode;
    BO_COAP_VERIFY(cbor_value_get_uint64(&value, &mode));

    BO_COAP_VERIFY(led_switch_mode((uint8_t)mode));
    coap_pdu_set_code(response, BO_COAP_CODE_204_CHANGED);
}

static void coap_hnd_temporary_duration_get(coap_resource_t* resource, coap_session_t* session,
                                            const coap_pdu_t* request, const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    const struct led_user_settings* settings = led_get_settings();

    uint8_t buf[128];

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    BO_COAP_TRY_ENCODE_CBOR(cbor_encode_uint(&encoder, settings->temporary_duration));
    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
}

static void coap_hnd_temporary_duration_put(coap_resource_t* resource, coap_session_t* session,
                                            const coap_pdu_t* request, const coap_string_t* query, coap_pdu_t* response)
{
    coap_resource_notify_observers(resource, NULL);

    size_t data_size;
    const uint8_t* data;
    coap_get_data(request, &data_size, &data);

    CborParser parser;
    CborValue value;
    BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &value));
    int duration;
    BO_COAP_VERIFY(cbor_value_get_int_checked(&value, &duration));

    if (duration <= 0 || duration > 0xFFFF) {
        coap_pdu_set_code(response, BO_COAP_CODE_400_BAD_REQUEST);
        return;
    }
    BO_COAP_TRY(led_set_temporary_duration((uint16_t)duration), COAP_RESPONSE_CODE_INTERNAL_ERROR);
    coap_pdu_set_code(response, BO_COAP_CODE_204_CHANGED);
}

static void coap_hnd_geo_location_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                      const coap_string_t* query, coap_pdu_t* response)
{
    size_t encoded_size = 0;
    uint8_t buf[128];

    // TODO lock

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

    if (led_has_geo_location()) {
        CborEncoder root_map;
        BO_COAP_VERIFY(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength));

        BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "lat"));
        BO_COAP_VERIFY(cbor_encode_float(&root_map, _led.settings.location.lat));

        BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "lng"));
        BO_COAP_VERIFY(cbor_encode_float(&root_map, _led.settings.location.lng));

        BO_COAP_VERIFY(cbor_encoder_close_container(&encoder, &root_map));
    }
    else {
        BO_COAP_VERIFY(cbor_encode_null(&encoder));
    }

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_geo_location_put(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                      const coap_string_t* query, coap_pdu_t* response)
{
    coap_resource_notify_observers(resource, NULL);

    size_t data_size;
    const uint8_t* data;
    coap_get_data(request, &data_size, &data);

    CborParser parser;
    CborValue iter;
    BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &iter));
    if (!cbor_value_is_map(&iter)) {
        coap_pdu_set_code(response, BO_COAP_CODE_400_BAD_REQUEST);
        return;
    }

    CborValue value;
    struct geo_location location;

    BO_COAP_VERIFY(cbor_value_map_find_value(&iter, "lat", &value));
    BO_COAP_VERIFY(cbor_value_get_float(&value, &location.lat));

    BO_COAP_VERIFY(cbor_value_map_find_value(&iter, "lng", &value));
    BO_COAP_VERIFY(cbor_value_get_float(&value, &location.lng));

    BO_COAP_TRY(led_set_geo_location(&location), COAP_RESPONSE_CODE_INTERNAL_ERROR);

    coap_pdu_set_code(response, BO_COAP_CODE_204_CHANGED);
}

COAP_RESOURCE_DEFINE("borneo/lyfi/color", false, coap_hnd_color_get, NULL, coap_hnd_color_put, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/schedule", false, coap_hnd_schedule_get, NULL, coap_hnd_schedule_put, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/info", false, coap_hnd_info_get, NULL, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/status", false, coap_hnd_status_get, NULL, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/state", false, coap_hnd_state_get, NULL, coap_hnd_state_put, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/correction-method", false, coap_hnd_correction_method_get, NULL,
                     coap_hnd_correction_method_put, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/mode", false, coap_hnd_mode_get, NULL, coap_hnd_mode_put, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/temporary-duration", false, coap_hnd_temporary_duration_get, NULL,
                     coap_hnd_temporary_duration_put, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/geo-location", false, coap_hnd_geo_location_get, NULL, coap_hnd_geo_location_put,
                     NULL);