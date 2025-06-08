import 'dart:async';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_common/utils/disposable.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/models/wot/device.dart';

class WotAdapter implements IDisposable {
  bool _disposed = false;
  final WotDevice device;
  final DeviceEventBus deviceEvents;
  final List<StreamSubscription> subscriptions = [];

  WotAdapter(this.device, {required this.deviceEvents});

  void addSubscription<T>(void Function(T) notifier) {
    if (_disposed) {
      throw ObjectDisposedException();
    }
    subscriptions.add(deviceEvents.on<T>().listen(notifier));
  }

  void addPropertyEventSubscription<TEvent>(
      String property, dynamic Function(TEvent) selector) {
    addSubscription<TEvent>(
        (e) => device.properties[property]!.setValue(selector(e)));
  }

  @override
  void dispose() {
    if (!_disposed) {
      for (final sub in subscriptions) {
        sub.cancel();
      }

      device.dispose();

      _disposed = true;
    }
  }
}
