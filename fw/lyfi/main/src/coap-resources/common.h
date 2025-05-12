#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int coap_led_sch_item_encode(CborEncoder* encoder, const struct led_scheduler_item* sch_item);
int coap_color_encode(CborEncoder* encoder, const led_color_t color);

#ifdef __cplusplus
}
#endif