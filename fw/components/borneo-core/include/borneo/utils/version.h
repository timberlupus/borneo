#pragma once

#ifdef __cplusplus
extern "C" {
#endif

struct version {
    uint16_t major;
    uint16_t minor;
    uint32_t patch;
};

int version_parse(struct version* ver, const char* src);

int version_compare(const struct version* lhs, const struct version* rhs);

#ifdef __cplusplus
}
#endif