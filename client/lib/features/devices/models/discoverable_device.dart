import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';

enum DiscoverableDeviceType {
  unprovisioned, // Found via BLE
  provisioned, // Found via mDNS (unregistered but on network)
}

class DiscoverableDevice {
  final DiscoverableDeviceType type;

  // For BLE devices, we initially only have the bluetooth name.
  final String? bleName;

  // For mDNS devices (provisioned), we have the full descriptor.
  final SupportedDeviceDescriptor? provisionedData;

  const DiscoverableDevice.unprovisioned(this.bleName)
    : type = DiscoverableDeviceType.unprovisioned,
      provisionedData = null;

  const DiscoverableDevice.provisioned(this.provisionedData)
    : type = DiscoverableDeviceType.provisioned,
      bleName = null;

  String get name => type == DiscoverableDeviceType.unprovisioned
      ? (bleName ?? 'Unknown Device')
      : (provisionedData?.name ?? 'Unknown Device');

  String get id =>
      type == DiscoverableDeviceType.unprovisioned ? (bleName ?? '') : (provisionedData?.fingerprint ?? '');
}
