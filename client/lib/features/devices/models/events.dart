import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';

import 'device_entity.dart';

class NewDeviceFoundEvent {
  final SupportedDeviceDescriptor device;
  const NewDeviceFoundEvent(this.device);
}

class UnprovisionedDeviceFoundEvent {
  final String deviceName;
  const UnprovisionedDeviceFoundEvent(this.deviceName);
}

class ProvisioningProgressEvent {
  final dynamic state; // To avoid circular dependency, or use dynamic/int
  // Better to import if possible, but let's keep it simple for event bus.
  // Actually, I can import BleProvisioningState.
  const ProvisioningProgressEvent(this.state);
}

class NewDeviceEntityAddedEvent {
  final DeviceEntity device;
  const NewDeviceEntityAddedEvent(this.device);
}

class DeviceEntityUpdatedEvent {
  final DeviceEntity old;
  final DeviceEntity updated;
  const DeviceEntityUpdatedEvent(this.old, this.updated);

  bool get hasNameChanged => old.name != updated.name;
  bool get hasGroupChanged => old.groupID != updated.groupID;
  bool get hasAddressChanged => old.address != updated.address;
}

class DeviceEntityDeletedEvent {
  final String id;
  const DeviceEntityDeletedEvent(this.id);
}
