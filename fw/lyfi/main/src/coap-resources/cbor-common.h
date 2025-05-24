#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int cbor_encode_led_sch_item(CborEncoder* encoder, const struct led_scheduler_item* sch_item);
int cbor_encode_color(CborEncoder* encoder, const led_color_t color);
int cbor_value_get_led_color(CborValue* value, led_color_t color);

#ifdef __cplusplus
}
#endif