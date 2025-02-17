#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int32_t linear_interpolate_i32(int32_t tA, int32_t VA, int32_t tB, int32_t VB, int32_t t);
uint32_t linear_interpolate_u32(uint32_t tA, uint32_t VA, uint32_t tB, uint32_t VB, uint32_t t);

#ifdef __cplusplus
}
#endif