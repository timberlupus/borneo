#include <stdint.h>

#include "algo.h"

int32_t linear_interpolate_i32(int32_t tA, int32_t VA, int32_t tB, int32_t VB, int32_t t)
{
    if (tA == tB) {
        return VA;
    }
    // V = VA + (VB - VA) * (t - tA) / (tB - tA)
    return VA + ((VB - VA) * (t - tA)) / (tB - tA);
}

uint32_t linear_interpolate_u32(uint32_t tA, uint32_t VA, uint32_t tB, uint32_t VB, uint32_t t)
{
    if (tA == tB) {
        return VA;
    }
    // V = VA + (VB - VA) * (t - tA) / (tB - tA)
    return VA + ((VB - VA) * (t - tA)) / (tB - tA);
}