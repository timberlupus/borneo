import 'package:borneo_kernel_abstractions/events.dart';

class DevicePowerOnOffChangedEvent extends DeviceStateChangedEvent {
  final bool onOff;
  const DevicePowerOnOffChangedEvent(super.device, {required this.onOff});
}
