import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';

import 'models/discovered_device.dart';

class FoundDeviceEvent {
  final DiscoveredDevice discovered;
  const FoundDeviceEvent(this.discovered);
}

class UnboundDeviceDiscoveredEvent {
  final SupportedDeviceDescriptor matched;
  const UnboundDeviceDiscoveredEvent(this.matched);
}

class DeviceBoundEvent {
  final Device device;
  const DeviceBoundEvent(this.device);
}

class DeviceRemovedEvent {
  final Device device;
  const DeviceRemovedEvent(this.device);
}

class DeviceOfflineEvent {
  final Device device;
  const DeviceOfflineEvent(this.device);
}

class LoadingDriverFailedEvent {
  final Device device;
  final Object? error;
  final String? message;
  const LoadingDriverFailedEvent(this.device, {this.error, this.message});
}

class DeviceDiscoveringStartedEvent {
  const DeviceDiscoveringStartedEvent();
}

class DeviceDiscoveringStoppedEvent {
  const DeviceDiscoveringStoppedEvent();
}
