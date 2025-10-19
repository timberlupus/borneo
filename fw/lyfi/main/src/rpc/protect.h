#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT

// RPC function declarations for LyFi protection CBOR operations
int bo_rpc_borneo_lyfi_protection_overheated_temp_get(const CborValue* args, CborEncoder* retvals);

#endif // CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT

#ifdef __cplusplus
}
#endif