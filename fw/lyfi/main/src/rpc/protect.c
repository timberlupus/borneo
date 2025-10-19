#include <esp_system.h>
#include <esp_event.h>
#include <esp_log.h>
#include <sys/socket.h>

#include <coap3/coap.h>
#include <cbor.h>

#include <borneo/common.h>
#include "../protect.h"
#include "rpc.h"

#if CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT

#define TAG "lyfi-rpc-protect"

int bo_rpc_borneo_lyfi_protection_overheated_temp_get(const CborValue* args, CborEncoder* retvals)
{
    (void)args; // No input args for GET
    BO_TRY(cbor_encode_uint(retvals, bo_protect_get_overheated_temp()));
    return 0;
}

#endif // CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT