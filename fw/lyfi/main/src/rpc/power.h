#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT

// RPC function declarations for LyFi power measurement CBOR operations
int bo_rpc_lyfi_power_mw_get(const CborValue* args, CborEncoder* retvals);

#endif // CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT

#ifdef __cplusplus
}
#endif