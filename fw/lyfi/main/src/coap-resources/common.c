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
#include "common.h"

int coap_led_sch_item_encode(CborEncoder* encoder, const struct led_scheduler_item* sch_item)
{
    CborEncoder item_map;
    BO_TRY(cbor_encoder_create_map(encoder, &item_map, CborIndefiniteLength));

    BO_TRY(cbor_encode_text_stringz(&item_map, "instant"));
    BO_TRY(cbor_encode_uint(&item_map, sch_item->instant));

    BO_TRY(cbor_encode_text_stringz(&item_map, "color"));
    BO_TRY(coap_color_encode(&item_map, sch_item->color));

    BO_TRY(cbor_encoder_close_container(encoder, &item_map));

    return 0;
}

int coap_color_encode(CborEncoder* encoder, const led_color_t color)
{
    CborEncoder ch_array;
    BO_TRY(cbor_encoder_create_array(encoder, &ch_array, LYFI_LED_CHANNEL_COUNT));
    for (size_t ch = 0; ch < LYFI_LED_CHANNEL_COUNT; ch++) {
        BO_TRY(cbor_encode_uint(&ch_array, color[ch]));
    }
    BO_TRY(cbor_encoder_close_container(encoder, &ch_array));
    return 0;
}
