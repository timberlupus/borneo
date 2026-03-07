import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:borneo_kernel_abstractions/event_dispatcher.dart';
import 'package:event_bus/event_bus.dart';

import 'models/discovered_device.dart';

class DeviceEventBus extends EventBus {}

/// @deprecated Use [EventDispatcher] / [DefaultEventDispatcher] instead.
///
/// This class remains for compatibility during the kernel-refactor branch,
/// but new code should rely on the abstration interfaces and inject a
/// dispatcher instance.  It will be removed once the migration completes.
@Deprecated('Use EventDispatcher and DefaultEventDispatcher (will be removed)')
class GlobalDevicesEventBus extends EventBus implements EventDispatcher {}

class FoundDeviceEvent {
  final DiscoveredDevice discovered;
  const FoundDeviceEvent(this.discovered);
}

class LostDeviceEvent {
  final DiscoveredDevice discovered;
  const LostDeviceEvent(this.discovered);
}

class UnboundDeviceDiscoveredEvent {
  final SupportedDeviceDescriptor matched;
  const UnboundDeviceDiscoveredEvent(this.matched);
}

class KnownDeviceDiscoveryUpdatedEvent extends KnownDeviceEvent {
  final SupportedDeviceDescriptor matched;
  const KnownDeviceDiscoveryUpdatedEvent(super.device, this.matched);
}

abstract class KnownDeviceEvent {
  final Device device;
  const KnownDeviceEvent(this.device);
}

abstract class DeviceStateChangedEvent extends KnownDeviceEvent {
  const DeviceStateChangedEvent(super.device);
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

class DeviceCommunicationEvent extends KnownDeviceEvent {
  const DeviceCommunicationEvent(super.device);
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

/// Fired when a previously discovered (but unbound) device disappears from
/// a discovery bus.  The listener receives the lost device fingerprint.
class UnboundDeviceLostEvent {
  final String deviceId;
  const UnboundDeviceLostEvent(this.deviceId);
}
