#include <stdint.h>
#include <stdbool.h>
#include <math.h>
#include <errno.h>

#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>

#include <cbor.h>

#include <borneo/system.h>

#include <borneo/common.h>

#include "../led/led.h"

#define TAG "acclimation-rpc"

int bo_rpc_borneo_lyfi_acclimation_get(const CborValue* args, CborEncoder* retvals)
{
    (void)args;

    CborEncoder root_map;
    BO_TRY(cbor_encoder_create_map(retvals, &root_map, CborIndefiniteLength));

    BO_TRY(cbor_encode_text_stringz(&root_map, "enabled"));
    BO_TRY(cbor_encode_boolean(&root_map, led_acclimation_is_enabled()));

    BO_TRY(cbor_encode_text_stringz(&root_map, "startTimestamp"));
    BO_TRY(cbor_encode_int(&root_map, _led.settings.acclimation.start_utc));

    BO_TRY(cbor_encode_text_stringz(&root_map, "days"));
    BO_TRY(cbor_encode_int(&root_map, _led.settings.acclimation.duration));

    BO_TRY(cbor_encode_text_stringz(&root_map, "startPercent"));
    BO_TRY(cbor_encode_int(&root_map, _led.settings.acclimation.start_percent));

    BO_TRY(cbor_encoder_close_container(retvals, &root_map));

    return 0;
}

int bo_rpc_borneo_lyfi_acclimation_post(const CborValue* args, CborEncoder* retvals)
{
    if (!cbor_value_is_map(args)) {
        return -1;
    }

    CborValue value;
    bool enabled;
    time_t start_time;
    int duration, start_percent;

    BO_TRY(cbor_value_map_find_value(args, "enabled", &value));
    BO_TRY(cbor_value_get_boolean(&value, &enabled));

    BO_TRY(cbor_value_map_find_value(args, "startTimestamp", &value));
    BO_TRY(cbor_value_get_int64_checked(&value, &start_time));

    BO_TRY(cbor_value_map_find_value(args, "days", &value));
    BO_TRY(cbor_value_get_int_checked(&value, &duration));

    BO_TRY(cbor_value_map_find_value(args, "startPercent", &value));
    BO_TRY(cbor_value_get_int_checked(&value, &start_percent));

    if (start_time <= 0) {
        return -ERANGE;
    }

    if (duration > LED_ACCLIMATION_DAYS_MAX || duration < LED_ACCLIMATION_DAYS_MIN) {
        return -ERANGE;
    }

    if (start_percent < 10 || start_percent > 90) {
        return -ERANGE;
    }

    struct led_acclimation_settings acc = {
        .start_utc = start_time,
        .duration = (uint8_t)duration,
        .start_percent = (uint8_t)start_percent,
    };

    BO_TRY(led_acclimation_set(&acc, enabled));

    return 0;
}

int bo_rpc_borneo_lyfi_acclimation_delete(const CborValue* args, CborEncoder* retvals)
{
    (void)args;

    BO_TRY(led_acclimation_terminate());

    return 0;
}