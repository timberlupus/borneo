#pragma once

#ifdef __cplusplus
extern "C" {
#endif

// RPC function declarations for reusable CBOR operations
int bo_rpc_borneo_info_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_reboot_post(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_status_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_fw_ver_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_compatible_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_heartbeat_get(const CborValue* args, CborEncoder* retvals);

#ifdef __cplusplus
}
#endif