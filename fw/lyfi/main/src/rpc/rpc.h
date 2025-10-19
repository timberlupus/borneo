#pragma once

#ifdef __cplusplus
extern "C" {
#endif

#if CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT

// RPC function declarations for LyFi power measurement CBOR operations
int bo_rpc_lyfi_power_mw_get(const CborValue* args, CborEncoder* retvals);

#endif // CONFIG_BORNEO_MEAS_VOLTAGE_SUPPORT && CONFIG_LYFI_MEAS_CURRENT_SUPPORT

// RPC function declarations for LyFi fan CBOR operations
int bo_rpc_borneo_lyfi_fan_power_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_lyfi_fan_power_put(const CborValue* args, CborEncoder* retvals);

#if CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT

// RPC function declarations for LyFi protection CBOR operations
int bo_rpc_borneo_lyfi_protection_overheated_temp_get(const CborValue* args, CborEncoder* retvals);

#endif // CONFIG_LYFI_PROTECTION_OVERHEATED_SUPPORT

#if CONFIG_LYFI_THERMAL_ENABLED

// RPC function declarations for LyFi thermal CBOR operations
int bo_rpc_borneo_lyfi_thermal_current_temp_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_lyfi_thermal_keep_temp_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_lyfi_thermal_settings_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_lyfi_thermal_fan_mode_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_lyfi_thermal_fan_mode_put(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_lyfi_thermal_manual_fan_get(const CborValue* args, CborEncoder* retvals);
int bo_rpc_borneo_lyfi_thermal_manual_fan_put(const CborValue* args, CborEncoder* retvals);

#endif // CONFIG_LYFI_THERMAL_ENABLED

#ifdef __cplusplus
}
#endif
