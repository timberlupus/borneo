#pragma once

#ifdef __cplusplus
extern "C" {
#endif

uint32_t bo_rtc_get_timestamp();

const char* bo_rtc_get_tz();
void bo_rtc_set_tz(const char* tz);

#ifdef __cplusplus
}
#endif