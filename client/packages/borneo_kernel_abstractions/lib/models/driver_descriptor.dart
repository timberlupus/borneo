import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';

import '../idriver.dart';
import 'discovered_device.dart';

class DriverDescriptor {
  final String id;
  final String name;
  final HeartbeatMethod heartbeatMethod;
  final DeviceDiscoveryMethod discoveryMethod;
  final SupportedDeviceDescriptor? Function(DiscoveredDevice) matches;
  final IDriver Function() factory;

  const DriverDescriptor({
    required this.id,
    required this.name,
    required this.heartbeatMethod,
    required this.discoveryMethod,
    required this.matches,
    required this.factory,
  });
}

sealed class DeviceDiscoveryMethod {
  const DeviceDiscoveryMethod();
}

class MdnsDeviceDiscoveryMethod extends DeviceDiscoveryMethod {
  final String serviceType;
  const MdnsDeviceDiscoveryMethod(this.serviceType);
}

/*
class BleDeviceDiscoveryMethod extends DeviceDiscoveryMethod {
  final String service;
  final String char;
  final String gatt;
  const BleDeviceDiscoveryMethod(this.service, this.char, this.gatt);
}
*/
