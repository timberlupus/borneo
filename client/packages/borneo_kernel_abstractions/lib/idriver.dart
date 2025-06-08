import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/models/wot/device.dart';
import 'package:cancellation_token/cancellation_token.dart';

abstract class IDriver implements IDisposable {
  const IDriver();

  Future<bool> probe(Device dev, GlobalDevicesEventBus globalBus,
      {CancellationToken? cancelToken});

  Future<bool> remove(Device dev, {CancellationToken? cancelToken});

  Future<bool> heartbeat(Device dev, {CancellationToken? cancelToken});

  Future<WotDevice> createWotDevice(Device device, DeviceEventBus deviceEvents,
      {CancellationToken? cancelToken});
}
