import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_common/utils/disposable.dart';
import 'package:synchronized/synchronized.dart';

import '../device.dart';

abstract class DriverData extends IDisposable {
  bool _isDisposed = false;
  final _lock = Lock();

  final Device device;
  final DeviceEventBus deviceEvents = DeviceEventBus();
  bool get isBusy => _lock.locked;
  Lock get lock => _lock;

  DriverData(this.device);

  @override
  void dispose() {
    if (_isDisposed) {
      // TODO add lock cancellation
      deviceEvents.destroy();
      _isDisposed = true;
    }
  }
}
