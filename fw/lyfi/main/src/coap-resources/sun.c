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
#include "../solar.h"
#include "cbor-common.h"

#define TAG "lyfi-coap"

extern struct led_status _led;

static void coap_hnd_sun_schedule_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                      const coap_string_t* query, coap_pdu_t* response)
{
    size_t encoded_size = 0;
    uint8_t buf[1024];

    // TODO lock
    extern struct led_status _led;

    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    CborEncoder root_array;
    BO_COAP_TRY(cbor_encoder_create_array(&encoder, &root_array, _led.sun_scheduler.item_count), response);
    for (size_t i = 0; i < _led.sun_scheduler.item_count; i++) {
        const struct led_scheduler_item* sch_item = &_led.sun_scheduler.items[i];
        BO_COAP_TRY(cbor_encode_led_sch_item(&root_array, sch_item), response);
    }
    BO_COAP_TRY(cbor_encoder_close_container(&encoder, &root_array), response);

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

static int sun_curve_item_encode(CborEncoder* encoder, const struct solar_instant* curve_item)
{
    CborEncoder item_map;
    BO_TRY(cbor_encoder_create_map(encoder, &item_map, CborIndefiniteLength));

    BO_TRY(cbor_encode_text_stringz(&item_map, "time"));
    BO_TRY(cbor_encode_float(&item_map, curve_item->time));

    BO_TRY(cbor_encode_text_stringz(&item_map, "brightness"));
    BO_TRY(cbor_encode_float(&item_map, curve_item->brightness));

    BO_TRY(cbor_encoder_close_container(encoder, &item_map));

    return 0;
}

static void coap_hnd_sun_curve_get(coap_resource_t* resource, coap_session_t* session, const coap_pdu_t* request,
                                   const coap_string_t* query, coap_pdu_t* response)
{

    if (!led_has_geo_location()) {
        coap_pdu_set_code(response, COAP_RESPONSE_CODE_BAD_REQUEST);
        return;
    }

    time_t utc_now = time(NULL);
    struct tm local_tm;

    localtime_r(&utc_now, &local_tm);

    float local_tz_offset = solar_calculate_local_tz_offset(&local_tm);

    float target_tz_offset
        = _led.settings.flags & LED_OPTION_TZ_ENABLED ? _led.settings.tz_offset / 3600.0f : local_tz_offset;

    float sunrise, noon, sunset, decl;

    int rc
        = solar_calculate_sunrise_sunset(_led.settings.location.lat, _led.settings.location.lng, utc_now,
                                         target_tz_offset, local_tz_offset, &local_tm, &sunrise, &noon, &sunset, &decl);
    if (rc) {
        coap_pdu_set_code(response, COAP_RESPONSE_CODE_INTERNAL_ERROR);
        return;
    }

    struct solar_instant instants[SOLAR_INSTANTS_COUNT];
    rc = solar_generate_instants(_led.settings.location.lat, decl, sunrise, noon, sunset, instants);
    if (rc) {
        coap_pdu_set_code(response, COAP_RESPONSE_CODE_INTERNAL_ERROR);
        return;
    }

    size_t encoded_size = 0;
    uint8_t buf[512];
    CborEncoder encoder;
    cbor_encoder_init(&encoder, buf, sizeof(buf), 0);
    CborEncoder root_array;
    BO_COAP_TRY(cbor_encoder_create_array(&encoder, &root_array, _led.sun_scheduler.item_count), response);
    for (size_t i = 0; i < SOLAR_INSTANTS_COUNT; i++) {
        BO_COAP_TRY(sun_curve_item_encode(&root_array, &instants[i]), response);
    }
    BO_COAP_TRY(cbor_encoder_close_container(&encoder, &root_array), response);

    encoded_size = cbor_encoder_get_buffer_size(&encoder, buf);

    coap_add_data_blocked_response(request, response, COAP_MEDIATYPE_APPLICATION_CBOR, 0, encoded_size, buf);
}

COAP_RESOURCE_DEFINE("borneo/lyfi/sun/schedule", false, coap_hnd_sun_schedule_get, NULL, NULL, NULL);

COAP_RESOURCE_DEFINE("borneo/lyfi/sun/curve", false, coap_hnd_sun_curve_get, NULL, NULL, NULL);