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

#include "../led/led.h"
#include "../fan.h"

#define TAG "lyfi-coap"

static void coap_hnd_acclimation_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                     const coap_string_t* query, coap_pdu_t* response)
{
    size_t encoded_size = 0;
    uint8_t buf[128];

    // TODO lock
    extern struct led_status _led;

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

    CborEncoder root_map;
    BO_COAP_VERIFY(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength));

    BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "enabled"));
    BO_COAP_VERIFY(cbor_encode_boolean(&root_map, led_acclimation_is_enabled()));

    BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "startTimestamp"));
    BO_COAP_VERIFY(cbor_encode_int(&root_map, _led.settings.acclimation.start_utc));

    BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "days"));
    BO_COAP_VERIFY(cbor_encode_int(&root_map, _led.settings.acclimation.duration));

    BO_COAP_VERIFY(cbor_encode_text_stringz(&root_map, "startPercent"));
    BO_COAP_VERIFY(cbor_encode_int(&root_map, _led.settings.acclimation.start_percent));

    BO_COAP_VERIFY(cbor_encoder_close_container(&encoder, &root_map));

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static void coap_hnd_acclimation_post(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
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
    bool enabled;
    time_t start_time;
    int duration, start_percent;

    BO_COAP_VERIFY(cbor_value_map_find_value(&iter, "enabled", &value));
    BO_COAP_VERIFY(cbor_value_get_boolean(&value, &enabled));

    BO_COAP_VERIFY(cbor_value_map_find_value(&iter, "startTimestamp", &value));
    BO_COAP_VERIFY(cbor_value_get_int64_checked(&value, &start_time));

    BO_COAP_VERIFY(cbor_value_map_find_value(&iter, "days", &value));
    BO_COAP_VERIFY(cbor_value_get_int_checked(&value, &duration));

    BO_COAP_VERIFY(cbor_value_map_find_value(&iter, "startPercent", &value));
    BO_COAP_VERIFY(cbor_value_get_int_checked(&value, &start_percent));

    if (start_time <= 0) {
        coap_pdu_set_code(response, BO_COAP_CODE_400_BAD_REQUEST);
        return;
    }

    if (duration > LED_ACCLIMATION_DAYS_MAX || duration < LED_ACCLIMATION_DAYS_MIN) {
        coap_pdu_set_code(response, BO_COAP_CODE_400_BAD_REQUEST);
        return;
    }

    if (start_percent < 10 || start_percent > 90) {
        coap_pdu_set_code(response, BO_COAP_CODE_400_BAD_REQUEST);
        return;
    }

    struct led_acclimation_settings acc = {
        .start_utc = start_time,
        .duration = (uint8_t)duration,
        .start_percent = (uint8_t)start_percent,
    };

    BO_COAP_TRY(led_acclimation_set(&acc, enabled), COAP_RESPONSE_CODE_INTERNAL_ERROR);

    coap_pdu_set_code(response, BO_COAP_CODE_201_CREATED);
}

static void coap_hnd_acclimation_delete(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                        const coap_string_t* query, coap_pdu_t* response)
{
    // TODO lock
    BO_COAP_TRY(led_acclimation_terminate(), COAP_RESPONSE_CODE_INTERNAL_ERROR);

    coap_pdu_set_code(response, COAP_RESPONSE_CODE_DELETED);
}

COAP_RESOURCE_DEFINE("borneo/lyfi/acclimation", false, coap_hnd_acclimation_get, coap_hnd_acclimation_post, NULL,
                     coap_hnd_acclimation_delete);