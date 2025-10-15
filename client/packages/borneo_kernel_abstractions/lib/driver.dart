import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:cancellation_token/cancellation_token.dart';

abstract class Driver implements IDisposable {
  Driver();

  Future<bool> probe(Device dev, {CancellationToken? cancelToken});

  Future<bool> remove(Device dev, {CancellationToken? cancelToken});

  Future<bool> heartbeat(Device dev, {CancellationToken? cancelToken});

  Future<T> withBusyCheck<T>(Device dev, Future<T> Function() action, {CancellationToken? cancelToken}) async {
    if (dev.driverData.isBusy) {
      throw InvalidOperationException(message: "Device is busy");
    }
    return await dev.driverData.lock.synchronized(action);
  }

  Future<T> withQueue<T>(Device dev, Future<T> Function() action, {CancellationToken? cancelToken}) async {
    return await dev.driverData.queue.submit(() async {
      if (dev.driverData.isBusy) {
        throw InvalidOperationException(message: "Device is busy");
      }
      return await action();
    }, cancel: cancelToken);
  }
}
