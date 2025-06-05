import 'package:borneo_kernel_abstractions/events.dart';

sealed class DevicePowerOnOffChangedEvent extends KnownDeviceEvent {
  const DevicePowerOnOffChangedEvent(super.device);
}
