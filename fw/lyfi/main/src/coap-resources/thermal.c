#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <sys/socket.h>

#include "coap3/coap.h"
#include <cbor.h>

#include <borneo/common.h>
#include <borneo/coap.h>
#include "../thermal.h"
#include "../protect.h"

#define TAG "thermal-coap"

#if CONFIG_LYFI_THERMAL_ENABLED

static void _coap_hnd_thermal_current_temp_get(coap_resource_t* resource, coap_session_t* session,
                                               const coap_pdu_t* request, const coap_string_t* query,
                                               coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;

    uint8_t buf[128];

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    int temp = thermal_get_current_temp();
    BO_COAP_TRY(cbor_encode_uint(&encoder, temp), response);
    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
}

static void _coap_hnd_thermal_keep_temp_get(coap_resource_t* resource, coap_session_t* session,
                                            const coap_pdu_t* request, const coap_string_t* query, coap_pdu_t* response)
{
    CborEncoder encoder;
    size_t encoded_size = 0;
    const struct thermal_settings* settings = thermal_get_settings();

    uint8_t buf[128];

    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    BO_COAP_TRY(cbor_encode_uint(&encoder, settings->keep_temp), response);
    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
}

static void _coap_hnd_thermal_settings_get(coap_resource_t* resource, coap_session_t* session,
                                           const coap_pdu_t* request, const coap_string_t* query, coap_pdu_t* response)
{
    size_t encoded_size = 0;
    uint8_t buf[1024];

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

    CborEncoder root_map;
    BO_COAP_TRY(cbor_encoder_create_map(&encoder, &root_map, CborIndefiniteLength), response);

    const struct thermal_settings* settings = thermal_get_settings();

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "kp"), response);
        BO_COAP_TRY(cbor_encode_int(&root_map, settings->kp), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "ki"), response);
        BO_COAP_TRY(cbor_encode_int(&root_map, settings->ki), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "kd"), response);
        BO_COAP_TRY(cbor_encode_int(&root_map, settings->kd), response);
    }

    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "tempKeep"), response);
        BO_COAP_TRY(cbor_encode_int(&root_map, settings->keep_temp), response);
    }

#if CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT
    {
        BO_COAP_TRY(cbor_encode_text_stringz(&root_map, "tempOverheated"), response);
        BO_COAP_TRY(cbor_encode_int(&root_map, bo_protect_get_overheated_temp()), response);
    }
#endif // CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT

    BO_COAP_TRY(cbor_encoder_close_container(&encoder, &root_map), response);

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

COAP_RESOURCE_DEFINE("borneo/lyfi/thermal/temp/current", false, _coap_hnd_thermal_current_temp_get, NULL, NULL, NULL);
COAP_RESOURCE_DEFINE("borneo/lyfi/thermal/temp/keep", false, _coap_hnd_thermal_keep_temp_get, NULL, NULL, NULL);
COAP_RESOURCE_DEFINE("borneo/lyfi/thermal/settings", false, _coap_hnd_thermal_settings_get, NULL, NULL, NULL);

#endif // CONFIG_LYFI_THERMAL_ENABLED