import 'package:borneo_common/borneo_common.dart';
import 'package:event_bus/event_bus.dart';

import '../device.dart';
import '../device_capability.dart';
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
  final EventBus events = EventBus();

  BoundDevice(this.driverID, this.device, this.driver);

  T api<T extends IDeviceApi>() {
    assert(!_isDisposed);
    return driver as T;
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      events.destroy();
      _isDisposed = true;
    }
  }
}
