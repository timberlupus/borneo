#pragma once

#ifdef __cplusplus
extern "C" {
#endif

uint16_t median_filter_u16(uint16_t* buffer, size_t buffer_size);

int32_t ema_filter(int32_t current, int32_t* filtered, float alpha);

#ifdef __cplusplus
}
#endif