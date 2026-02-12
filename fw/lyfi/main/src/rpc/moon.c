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
#include <borneo/algo/astronomy.h>

#include "../led/led.h"
#include "../moon.h"
#include "../solar.h"
#include "cbor-common.h"

#define TAG "moon-rpc"

static int moon_curve_item_encode(CborEncoder* encoder, const struct moon_instant* curve_item)
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

int bo_rpc_borneo_lyfi_moon_schedule_get(const CborValue* args, CborEncoder* retvals)
{
    (void)args;
    CborEncoder root_array;
    BO_TRY(cbor_encoder_create_array(retvals, &root_array, _led.moon_scheduler.item_count));
    for (size_t i = 0; i < _led.moon_scheduler.item_count; i++) {
        const struct led_scheduler_item* sch_item = &_led.moon_scheduler.items[i];
        BO_TRY(cbor_encode_led_sch_item(&root_array, sch_item));
    }
    BO_TRY(cbor_encoder_close_container(retvals, &root_array));

    return 0;
}

int bo_rpc_borneo_lyfi_moon_curve_get(const CborValue* args, CborEncoder* retvals)
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

    float moonrise = 0.0f;
    float moonset = 0.0f;
    float decl = 0.0f;
    float illum = 0.0f;

    BO_TRY(moon_calculate_rise_set(_led.settings.location.lat, _led.settings.location.lng, utc_now, target_tz_offset,
                                   local_tz_offset, &local_tm, &moonrise, &moonset, &decl, &illum));

    struct moon_instant instants[MOON_INSTANTS_COUNT];
    BO_TRY(moon_generate_instants(moonrise, moonset, illum, instants));

    CborEncoder root_array;
    BO_TRY(cbor_encoder_create_array(retvals, &root_array, MOON_INSTANTS_COUNT));
    for (size_t i = 0; i < MOON_INSTANTS_COUNT; i++) {
        BO_TRY(moon_curve_item_encode(&root_array, &instants[i]));
    }
    BO_TRY(cbor_encoder_close_container(retvals, &root_array));

    return 0;
}

int bo_rpc_borneo_lyfi_moon_get(const CborValue* args, CborEncoder* retvals)
{
    (void)args;

    CborEncoder root_map;
    BO_TRY(cbor_encoder_create_map(retvals, &root_map, CborIndefiniteLength));

    BO_TRY(cbor_encode_text_stringz(&root_map, "enabled"));
    BO_TRY(cbor_encode_boolean(&root_map, led_moon_is_enabled()));

    BO_TRY(cbor_encode_text_stringz(&root_map, "color"));
    BO_TRY(cbor_encode_color(&root_map, _led.settings.moon_color));

    BO_TRY(cbor_encoder_close_container(retvals, &root_map));

    return 0;
}

int bo_rpc_borneo_lyfi_moon_put(const CborValue* args, CborEncoder* retvals)
{
    if (!cbor_value_is_map(args)) {
        return -EINVAL;
    }

    CborValue value;
    bool enabled = false;
    led_color_t color;

    BO_TRY(cbor_value_map_find_value(args, "enabled", &value));
    BO_TRY(cbor_value_get_boolean(&value, &enabled));

    BO_TRY(cbor_value_map_find_value(args, "color", &value));
    BO_TRY(cbor_value_get_led_color(&value, color));

    BO_TRY(led_moon_set(color, enabled));

    return 0;
}

int bo_rpc_borneo_lyfi_moon_status_get(const CborValue* args, CborEncoder* retvals)
{
    (void)args;

    time_t utc_now = time(NULL);
    float jd_now = astronomy_julian_date(utc_now);

    CborEncoder root_map;
    BO_TRY(cbor_encoder_create_map(retvals, &root_map, CborIndefiniteLength));

    BO_TRY(cbor_encode_text_stringz(&root_map, "phaseAngle"));
    BO_TRY(cbor_encode_float(&root_map, moon_phase_angle(jd_now)));

    BO_TRY(cbor_encode_text_stringz(&root_map, "illumination"));
    BO_TRY(cbor_encode_float(&root_map, moon_illumination(jd_now)));

    BO_TRY(cbor_encoder_close_container(retvals, &root_map));

    return 0;
}
