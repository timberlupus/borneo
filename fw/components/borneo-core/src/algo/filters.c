// https://stackoverflow.com/questions/7960318/math-to-convert-seconds-since-1970-into-date-and-vice-versa

#include "borneo/common.h"
#include "borneo/algo/filters.h"

uint16_t median_filter_u16(uint16_t* buffer, size_t buffer_size)
{
    for (size_t j = 0; j < buffer_size - 1; j++) {
        for (size_t i = 0; i < (buffer_size - j); i++) {
            if (buffer[i] > buffer[i + 1]) {
                // Swap
                uint16_t tmp = buffer[i];
                buffer[i] = buffer[i + 1];
                buffer[i + 1] = tmp;
            }
        }
    }
    return buffer[(buffer_size - 1) / 2];
}
