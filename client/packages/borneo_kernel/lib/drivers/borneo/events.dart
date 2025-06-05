import 'package:borneo_kernel_abstractions/events.dart';

class DevicePowerOnOffChangedEvent extends KnownDeviceEvent {
  final bool onOff;
  const DevicePowerOnOffChangedEvent(super.device, this.onOff);
}
