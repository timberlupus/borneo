/*- Project:    A simple SNTP client
  - Author:     Richard James Howe
  - License:    The Unlicense
  - Email:      howe.r.j.89@gmail.com
  - Repository: https://github.com/howerj/sntp */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

enum {
    BO_SNTP_EVENT_SUCCEED,
    BO_SNTP_EVENT_FAILED,
};

ESP_EVENT_DECLARE_BASE(BO_SNTP_EVENTS);

int bo_sntp(const char* server, unsigned port, unsigned long* seconds, unsigned long* fractional);

int bo_sntp_init();
int bo_sntp_now();
bool bo_sntp_is_syncing();
bool bo_sntp_is_sync_needed();

#ifdef __cplusplus
}
#endif