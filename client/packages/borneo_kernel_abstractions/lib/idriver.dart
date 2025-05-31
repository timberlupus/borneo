import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';

abstract class IDriver implements IDisposable {
  const IDriver();

  Future<bool> probe(Device dev, EventBus deviceEvents,
      {CancellationToken? cancelToken});

  Future<bool> remove(Device dev, {CancellationToken? cancelToken});

  Future<bool> heartbeat(Device dev, {CancellationToken? cancelToken});
}
