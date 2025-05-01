#pragma once

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

enum bo_ota_status{
    BO_OTA_STATE_IDLE,
    BO_OTA_STATE_DOWNLOADING,
    BO_OTA_STATE_UPDATING,
};

struct bo_ota_runtime {

    unsigned int state;

    size_t total_bytes_received;

    size_t buffer_len;
    uint8_t buffer[];
};

#ifdef __cplusplus
}
#endif