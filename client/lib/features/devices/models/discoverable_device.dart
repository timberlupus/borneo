import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';

enum DiscoverableDeviceType {
  unprovisioned, // Found via BLE
  provisioned, // Found via mDNS (unregistered but on network)
}

class DiscoverableDevice {
  final DiscoverableDeviceType type;

  // For BLE devices, we initially only have the bluetooth name.
  final String? bleName;

  // After calling fetchDeviceInfo we may be able to resolve a human-friendly
  // name.  This is transient and only used for display.
  final String? resolvedName;

  // For mDNS devices (provisioned), we have the full descriptor.
  final SupportedDeviceDescriptor? provisionedData;

  const DiscoverableDevice.unprovisioned(this.bleName, {this.resolvedName})
    : type = DiscoverableDeviceType.unprovisioned,
      provisionedData = null;

  const DiscoverableDevice.provisioned(this.provisionedData)
    : type = DiscoverableDeviceType.provisioned,
      bleName = null,
      resolvedName = null;

  String get name => type == DiscoverableDeviceType.unprovisioned
      ? (resolvedName ?? bleName ?? 'Unknown Device')
      : (provisionedData?.name ?? 'Unknown Device');

  String get id =>
      type == DiscoverableDeviceType.unprovisioned ? (bleName ?? '') : (provisionedData?.fingerprint ?? '');
}
