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
#include "cbor.h"

int cbor_encode_led_sch_item(CborEncoder* encoder, const struct led_scheduler_item* sch_item)
{
    CborEncoder item_map;
    BO_TRY(cbor_encoder_create_map(encoder, &item_map, CborIndefiniteLength));

    BO_TRY(cbor_encode_text_stringz(&item_map, "instant"));
    BO_TRY(cbor_encode_uint(&item_map, sch_item->instant));

    BO_TRY(cbor_encode_text_stringz(&item_map, "color"));
    BO_TRY(cbor_encode_color(&item_map, sch_item->color));

    BO_TRY(cbor_encoder_close_container(encoder, &item_map));

    return 0;
}

int cbor_encode_color(CborEncoder* encoder, const led_color_t color)
{
    CborEncoder ch_array;
    BO_TRY(cbor_encoder_create_array(encoder, &ch_array, LYFI_LED_CHANNEL_COUNT));
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        BO_TRY(cbor_encode_uint(&ch_array, color[ch]));
    }
    BO_TRY(cbor_encoder_close_container(encoder, &ch_array));
    return 0;
}

int cbor_value_get_led_color(CborValue* value, led_color_t color)
{
    CborValue array;
    size_t array_length = 0;
    BO_TRY(cbor_value_enter_container(value, &array));
    BO_TRY(cbor_value_get_array_length(value, &array_length));
    if (array_length != LYFI_LED_CHANNEL_COUNT) {
        return -EINVAL;
    }

    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        int ch_value = 0;
        BO_TRY(cbor_value_get_int_checked(&array, &ch_value));
        if (ch_value < 0) {
            return -EINVAL;
        }
        color[ch] = ch_value;
        BO_TRY(cbor_value_advance_fixed(&array));
    }
    BO_TRY(cbor_value_leave_container(value, &array));
    return 0;
}
