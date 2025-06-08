import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/idevice_api.dart';
import 'package:borneo_kernel_abstractions/models/wot/device.dart';
import 'package:event_bus/event_bus.dart';

import '../device.dart';
import '../idriver.dart';

/// The meta data of the BoundDevice
final class BoundDeviceDescriptor {
  final Device device;
  final String driverID;
  BoundDeviceDescriptor({required this.device, required this.driverID});
}

final class BoundDevice implements IDisposable {
  bool _isDisposed = false;
  final String driverID;
  final Device device;
  final IDriver driver;
  final WotDevice wotDevice;
  final EventBus events;

  BoundDevice(
      this.driverID, this.device, this.driver, this.wotDevice, this.events);

  T api<T extends IDeviceApi>() {
    if (_isDisposed) {
      throw ObjectDisposedException();
    }
    return driver as T;
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      wotDevice.dispose();
      events.destroy();
      _isDisposed = true;
    }
  }
}
