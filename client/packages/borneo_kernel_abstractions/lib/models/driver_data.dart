import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_common/utils/disposable.dart';

import '../device.dart';

abstract class DriverData extends IDisposable {
  bool _isDisposed = false;

  final Device device;
  final DeviceEventBus deviceEvents = DeviceEventBus();

  DriverData(this.device);

  @override
  void dispose() {
    if (_isDisposed) {
      deviceEvents.destroy();
      _isDisposed = true;
    }
  }
}
