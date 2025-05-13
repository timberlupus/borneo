#include <stdint.h>

#include "algo.h"

int32_t linear_interpolate_i32(int32_t tA, int32_t VA, int32_t tB, int32_t VB, int32_t t)
{
    if (tA == tB) {
        return VA;
    }
    int64_t diff = (int64_t)(VB - VA) * (t - tA);
    int32_t denom = tB - tA;
    return VA + (int32_t)((diff + (diff > 0 ? denom / 2 : -denom / 2)) / denom);
}

uint32_t linear_interpolate_u32(uint32_t tA, uint32_t VA, uint32_t tB, uint32_t VB, uint32_t t)
{
    if (tA == tB) {
        return VA;
    }
    uint64_t diff = (uint64_t)(VB - VA) * (t - tA);
    uint32_t denom = tB - tA;
    return VA + (uint32_t)((diff + denom / 2) / denom);
}