import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/device_api.dart';

import '../device.dart';
import '../driver.dart';

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

  BoundDevice(this.driverID, this.device, this.driver);

  T api<T extends IDeviceApi>() {
    if (_isDisposed) {
      throw ObjectDisposedException();
    }
    return driver as T;
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _isDisposed = true;
    }
  }
}
