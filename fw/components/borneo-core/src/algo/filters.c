#include "borneo/common.h"
#include "borneo/algo/filters.h"

uint16_t median_filter_u16(uint16_t* buffer, size_t buffer_size)
{
    for (size_t i = 1; i < buffer_size; i++) {
        uint16_t key = buffer[i];
        size_t j = i;
        while (j > 0 && buffer[j - 1] > key) {
            buffer[j] = buffer[j - 1];
            j--;
        }
        buffer[j] = key;
    }
    return buffer[(buffer_size - 1) / 2];
}