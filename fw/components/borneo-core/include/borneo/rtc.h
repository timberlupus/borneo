#pragma once

#ifdef __cplusplus
extern "C" {
#endif

int bo_rtc_init();

uint32_t bo_rtc_get_timestamp();

const char* bo_rtc_get_tz();
int bo_rtc_set_tz(const char* tz);

#ifdef __cplusplus
}
#endif