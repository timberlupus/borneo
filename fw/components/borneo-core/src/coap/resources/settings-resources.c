#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_ota_ops.h>
#include <esp_mac.h>
#include <nvs_flash.h>
#include <sys/socket.h>

#include "coap3/coap.h"
#include <cbor.h>

#include <borneo/rtc.h>
#include <borneo/ntc.h>
#include <borneo/common.h>
#include <borneo/coap.h>
#include <borneo/wifi.h>
#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>

#define TAG "borneo-core-coap-settings"

static void coap_hnd_borneo_settings_timezone_get(coap_resource_t* resource, coap_session_t* session,
                                                  const coap_pdu_t* request, const coap_string_t* query,
                                                  coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    uint8_t buf[256] = { 0 };
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    const char* tz = bo_rtc_get_tz();
    if (tz != NULL) {
        BO_COAP_TRY(cbor_encode_text_stringz(&encoder, tz), response);
    }
    else {
        BO_COAP_TRY(cbor_encode_null(&encoder), response);
    }
    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);

    return;
}

static void coap_hnd_borneo_settings_timezone_put(coap_resource_t* resource, coap_session_t* session,
                                                  const coap_pdu_t* request, const coap_string_t* query,
                                                  coap_pdu_t* response)
{
    coap_resource_notify_observers(resource, NULL);

    size_t data_size;
    const uint8_t* data;
    coap_get_data(request, &data_size, &data);

    CborParser parser;
    CborValue value;
    BO_COAP_TRY(cbor_parser_init(data, data_size, 0, &parser, &value), response);

    char tz[256] = { 0 };
    size_t tz_len = sizeof(tz);

    BO_COAP_TRY_DECODE(cbor_value_copy_text_string(&value, tz, &tz_len, NULL), response);
    if (tz_len > 128 || tz_len == 0) {
        coap_pdu_set_code(response, COAP_RESPONSE_CODE(500));
        return;
    }
    bo_rtc_set_tz(tz);

    coap_pdu_set_code(response, COAP_RESPONSE_CODE(204));
    return;
}

COAP_RESOURCE_DEFINE("borneo/settings/timezone", false, coap_hnd_borneo_settings_timezone_get, NULL,
                     coap_hnd_borneo_settings_timezone_put, NULL);
