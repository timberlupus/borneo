import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:event_bus/event_bus.dart';

import 'models/discovered_device.dart';

class DeviceEventBus extends EventBus {}

class GlobalDevicesEventBus extends EventBus {}

class FoundDeviceEvent {
  final DiscoveredDevice discovered;
  const FoundDeviceEvent(this.discovered);
}

class UnboundDeviceDiscoveredEvent {
  final SupportedDeviceDescriptor matched;
  const UnboundDeviceDiscoveredEvent(this.matched);
}

abstract class KnownDeviceEvent {
  final Device device;
  const KnownDeviceEvent(this.device);
}

class DeviceBoundEvent extends KnownDeviceEvent {
  const DeviceBoundEvent(super.device);
}

class DeviceRemovedEvent extends KnownDeviceEvent {
  const DeviceRemovedEvent(super.device);
}

class DeviceOfflineEvent extends KnownDeviceEvent {
  const DeviceOfflineEvent(super.device);
}

class LoadingDriverFailedEvent extends KnownDeviceEvent {
  final Object? error;
  final String? message;
  const LoadingDriverFailedEvent(super.device, {this.error, this.message});
}

class DeviceDiscoveringStartedEvent {
  const DeviceDiscoveringStartedEvent();
}

class DeviceDiscoveringStoppedEvent {
  const DeviceDiscoveringStoppedEvent();
}
