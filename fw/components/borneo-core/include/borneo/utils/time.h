#pragma once

#ifdef __cplusplus
extern "C" {
#endif
/* Declarations of this file */

int64_t to_unix_time(int year, int month, int day, int hour, int min, int sec);

const char* bo_tz_get();
int bo_tz_set(const char* tz);

#ifdef __cplusplus
}
#endif
