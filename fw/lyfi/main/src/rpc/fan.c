#include <stdint.h>
#include <stdbool.h>
#include <errno.h>

#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>

#include <cbor.h>

#include <borneo/system.h>

#include "../fan.h"
#include "rpc.h"

#define TAG "lyfi-rpc-fan"

int bo_rpc_borneo_lyfi_fan_power_get(const CborValue* args, CborEncoder* retvals)
{
    (void)args; // No input args for GET
#if CONFIG_LYFI_FAN_CTRL_SUPPORT
    const struct fan_status status = fan_get_status();
    BO_TRY(cbor_encode_uint(retvals, status.power));
#else
    BO_TRY(cbor_encode_null(retvals));
#endif
    return 0;
}

int bo_rpc_borneo_lyfi_fan_power_put(const CborValue* args, CborEncoder* retvals)
{
    (void)retvals; // No output for PUT
#if CONFIG_LYFI_FAN_CTRL_SUPPORT
    int power;
    BO_TRY(cbor_value_get_int(args, &power));
    if (power > 100 || power < 0) {
        return -ERANGE; // Bad request
    }
    BO_TRY(fan_set_power((uint8_t)power));
#else
    return -ENOTSUP; // Not supported
#endif
    return 0;
}