import 'dart:async';

import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_common/utils/disposable.dart';

import '../device.dart';

abstract class DriverData extends IDisposable {
  bool _isDisposed = false;

  final Device device;
  final GlobalDevicesEventBus globalEvents;
  final DeviceEventBus deviceEvents = DeviceEventBus();
  late final StreamSubscription _relaySub;

  DriverData(this.device, this.globalEvents) {
    _relaySub = deviceEvents.on().listen((event) => globalEvents.fire(event));
  }

  @override
  void dispose() {
    if (_isDisposed) {
      _relaySub.cancel();
      deviceEvents.destroy();
      _isDisposed = true;
    }
  }
}
