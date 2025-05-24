#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <esp_ota_ops.h>
#include <esp_mac.h>
#include <nvs_flash.h>
#include <sys/socket.h>

#include <coap3/coap.h>
#include <cbor.h>

#include <borneo/rtc.h>
#include <borneo/ntc.h>
#include <borneo/common.h>
#include <borneo/coap.h>
#include <borneo/wifi.h>
#include <borneo/system.h>
#include <borneo/power.h>
#include <borneo/nvs.h>

#define TAG "borneo-power-coap"

static void coap_hnd_rtc_local_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                   const coap_string_t* query, coap_pdu_t* response)
{
    int64_t t1 = 0LL;
    int64_t t2 = bo_rtc_get_timestamp_us();
    int64_t t3 = 0LL;

    {
        size_t data_size;
        const uint8_t* data;
        coap_get_data(request, &data_size, &data);

        CborParser parser;
        CborValue value;
        BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &value));

        BO_COAP_VERIFY(cbor_value_get_int64_checked(&value, &t1));

        if (t1 <= 0LL) {
            coap_pdu_set_code(response, BO_COAP_CODE_400_BAD_REQUEST);
            return;
        }
    }

    {
        CborEncoder encoder;
        size_t encoded_size = 0;
        uint8_t buf[128] = { 0 };

        cbor_encoder_init(&encoder, buf, sizeof(buf), 0);

        CborEncoder map_encoder;
        BO_COAP_VERIFY(cbor_encoder_create_map(&encoder, &map_encoder, CborIndefiniteLength));
        BO_COAP_VERIFY(cbor_encode_text_stringz(&map_encoder, "t1"));
        BO_COAP_VERIFY(cbor_encode_uint(&map_encoder, t1));
        BO_COAP_VERIFY(cbor_encode_text_stringz(&map_encoder, "t2"));
        BO_COAP_VERIFY(cbor_encode_uint(&map_encoder, t2));

        BO_COAP_VERIFY(cbor_encode_text_stringz(&map_encoder, "t3"));
        t3 = bo_rtc_get_timestamp_us();
        BO_COAP_VERIFY(cbor_encode_uint(&map_encoder, t3));

        BO_COAP_VERIFY(cbor_encoder_close_container(&encoder, &map_encoder));

        encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

        coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
    }

    coap_pdu_set_code(response, COAP_RESPONSE_CODE_CONTENT);
    return;
}

static void coap_hnd_rtc_local_post(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                    const coap_string_t* query, coap_pdu_t* response)
{
    size_t data_size;
    const uint8_t* data;
    coap_get_data(request, &data_size, &data);

    CborParser parser;
    CborValue value;
    BO_COAP_VERIFY(cbor_parser_init(data, data_size, 0, &parser, &value));

    int64_t time_skew_us;

    BO_COAP_VERIFY(cbor_value_get_int64_checked(&value, &time_skew_us));

    if (time_skew_us < 1000LL) {

        coap_pdu_set_code(response, BO_COAP_CODE_400_BAD_REQUEST);
        return;
    }
    int64_t timestamp_us = bo_rtc_get_timestamp_us();
    timestamp_us += time_skew_us;
    BO_COAP_TRY(bo_rtc_set_time(timestamp_us), BO_COAP_CODE_400_BAD_REQUEST);

    coap_pdu_set_code(response, BO_COAP_CODE_201_CREATED);
}

COAP_RESOURCE_DEFINE("borneo/rtc/local", false, coap_hnd_rtc_local_get, coap_hnd_rtc_local_post, NULL, NULL);
