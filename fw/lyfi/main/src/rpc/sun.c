#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <errno.h>

#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>

#include <cbor.h>

#include <borneo/system.h>
#include <borneo/rtc.h>

#include "../led/led.h"
#include "../solar.h"
#include "cbor-common.h"

#define TAG "sun-rpc"

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

int bo_rpc_borneo_lyfi_sun_schedule_get(const CborValue* args, CborEncoder* retvals)
{
    (void)args;
    CborEncoder root_array;
    BO_TRY(cbor_encoder_create_array(retvals, &root_array, _led.sun_scheduler.item_count));
    for (size_t i = 0; i < _led.sun_scheduler.item_count; i++) {
        const struct led_scheduler_item* sch_item = &_led.sun_scheduler.items[i];
        BO_TRY(cbor_encode_led_sch_item(&root_array, sch_item));
    }
    BO_TRY(cbor_encoder_close_container(retvals, &root_array));

    return 0;
}

int bo_rpc_borneo_lyfi_sun_curve_get(const CborValue* args, CborEncoder* retvals)
{
    (void)args;
    if (!led_has_geo_location()) {
        return -EINVAL;
    }

    time_t utc_now = time(NULL);
    struct tm local_tm;

    localtime_r(&utc_now, &local_tm);

    float local_tz_offset = solar_calculate_local_tz_offset(&local_tm);

    float target_tz_offset
        = _led.settings.flags & LED_OPTION_TZ_ENABLED ? _led.settings.tz_offset / 3600.0f : local_tz_offset;

    float sunrise, noon, sunset, decl;

    BO_TRY(solar_calculate_sunrise_sunset(_led.settings.location.lat, _led.settings.location.lng, utc_now,
                                          target_tz_offset, local_tz_offset, &local_tm, &sunrise, &noon, &sunset,
                                          &decl));

    struct solar_instant instants[SOLAR_INSTANTS_COUNT];
    BO_TRY(solar_generate_instants(_led.settings.location.lat, decl, sunrise, noon, sunset, instants));

    CborEncoder root_array;
    BO_TRY(cbor_encoder_create_array(retvals, &root_array, _led.sun_scheduler.item_count));
    for (size_t i = 0; i < SOLAR_INSTANTS_COUNT; i++) {
        BO_TRY(sun_curve_item_encode(&root_array, &instants[i]));
    }
    BO_TRY(cbor_encoder_close_container(retvals, &root_array));

    return 0;
}