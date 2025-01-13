import 'package:borneo_kernel_abstractions/device.dart';

abstract class IDeviceApi {}

abstract class IReadOnlyPowerOnOffCapability extends IDeviceApi {
  Future<bool> getOnOff(Device dev);
}

abstract class IPowerOnOffCapability extends IReadOnlyPowerOnOffCapability {
  Future<void> setOnOff(Device dev, bool on);
}
