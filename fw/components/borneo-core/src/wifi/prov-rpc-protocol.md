# Borneo 网络配网 RPC 协议说明

## 概述

设备在 BLE 配网模式下，通过 `espressif__network_provisioning` 组件对外暴露一个名为 `rpc` 的自定义端点（endpoint）。客户端可通过该端点向设备发送 CBOR 编码的 RPC 请求，获取设备信息等数据。

- **传输层**：BLE（通过 `network_prov_scheme_ble`）
- **端点名称**：`rpc`
- **编码格式**：CBOR（[RFC 7049](https://datatracker.ietf.org/doc/html/rfc7049)），[JSON 仅用于本文档示意]
- **安全级别**：`NETWORK_PROV_SECURITY_0`（无加密，无 PoP）

---

## 数据包格式

所有请求和响应均编码为 CBOR 的**不定长 Map**（indefinite-length map）。

### 请求包

| 字段 | 类型 | 是否必须 | 说明 |
|------|------|----------|------|
| `v` | 整数（int） | 是 | 协议版本号，当前必须为 `1` |
| `id` | 无符号整数（uint32_t） | 是 | 请求 ID，用于将响应与请求对应 |
| `m` | 整数（int） | 是 | 方法索引，见下方方法列表 |

JSON 示意：
```json
{
  "v": 1,
  "id": 42,
  "m": 1
}
```

### 响应包

| 字段 | 类型 | 说明 |
|------|------|------|
| `v` | 整数（int） | 协议版本号，固定为 `1` |
| `id` | 无符号整数（uint32_t） | 与请求中的 `id` 一致 |
| `r` | 由方法决定 | 方法返回值；出错时为 CBOR `null` |
| `e` | 有符号整数（int32_t） | 错误码；`0` 表示成功，`-1` 表示错误 |

JSON 示意（成功）：
```json
{
  "v": 1,
  "id": 42,
  "r": { ... },
  "e": 0
}
```

JSON 示意（失败）：
```json
{
  "v": 1,
  "id": 42,
  "r": null,
  "e": -1
}
```

> **注意**：为安全起见，任何方法执行失败时错误码统一返回 `-1`，不暴露具体错误原因。

---

## 错误处理规则

以下情况设备将返回错误响应（`e: -1, r: null`），`id` 字段尽可能填充请求中的值（无法解析时为 `0`）：

| 情形 | `id` 值 |
|------|---------|
| `inbuf` 为空或长度为 0 | `0` |
| CBOR 解析失败或数据包不是 Map | `0` |
| 缺少 `v` 字段，或 `v != 1` | `0` |
| 缺少 `m` 字段 | 请求中的 `id`（若已提取） |
| 未知方法索引 | 请求中的 `id` |
| 方法执行内部错误 | 请求中的 `id` |

---

## 方法列表

### 方法 1：`BO_PROV_METHOD_GET_DEVICE_INFO`

获取设备基本信息。

**请求**

无额外参数，`m` 字段填 `1` 即可。

**响应 `r` 字段**

`r` 为一个 CBOR Map，包含以下字段：

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | 字符串 | 设备十六进制 ID |
| `compatible` | 字符串 | 设备兼容字符串（如 `"borneo,lyfi-bst"`） |
| `name` | 字符串 | 设备名称 |
| `serno` | 字符串 | 序列号（当前与 `id` 相同） |
| `productMode` | 无符号整数 | 产品模式：`0`=Standalone，`1`=Full，`2`=OEM |
| `hasBT` | 布尔 | 是否支持蓝牙 |
| `btMac` | 字节串（6 字节） | 蓝牙 MAC 地址（仅 `hasBT=true` 时存在） |
| `hasWifi` | 布尔 | 是否支持 Wi-Fi，固定为 `true` |
| `wifiMac` | 字节串（6 字节） | Wi-Fi MAC 地址 |
| `manuf` | 字符串 | 制造商名称 |
| `model` | 字符串 | 设备型号 |
| `hwVer` | 字符串 | 硬件版本号 |
| `fwVer` | 字符串 | 固件版本号 |
| `isCE` | 布尔 | 是否为 CE 版本固件 |

**完整示例**

请求（JSON 示意）：
```json
{ "v": 1, "id": 100, "m": 1 }
```

响应（JSON 示意）：
```json
{
  "v": 1,
  "id": 100,
  "r": {
    "id": "a1b2c3d4e5f6",
    "compatible": "borneo,lyfi-bst",
    "name": "Lyfi-BST",
    "serno": "a1b2c3d4e5f6",
    "productMode": 1,
    "hasBT": true,
    "btMac": "<6 bytes>",
    "hasWifi": true,
    "wifiMac": "<6 bytes>",
    "manuf": "Borneo",
    "model": "BST",
    "hwVer": "1.0",
    "fwVer": "0.5.0",
    "isCE": true
  },
  "e": 0
}
```

---

## 输出缓冲区限制

响应数据编码到固定大小的静态缓冲区（`resp_buf[1024]`），最大响应包为 **1024 字节**。若编码溢出则行为未定义，建议未来方法的响应内容规划在此限制以内。

---

## 实现位置

| 文件 | 说明 |
|------|------|
| `components/borneo-core/src/wifi/np.c` | 配网初始化、事件处理、RPC 分发实现 |
| `components/borneo-core/include/borneo/rpc/common.h` | `bo_rpc_borneo_info_get` 声明 |
| `components/borneo-core/src/rpc/common.c` | `bo_rpc_borneo_info_get` 实现 |
