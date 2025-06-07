import 'package:event_bus/event_bus.dart';
import 'package:borneo_common/utils/disposable.dart';

import '../device.dart';

abstract class DriverData extends IDisposable {
  final Device device;
  final EventBus deviceEventBus;

  DriverData(this.device, this.deviceEventBus);
}
