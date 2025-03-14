import 'package:async_queue/async_queue.dart';
import 'package:borneo_app/events.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';

abstract class BaseViewModel extends ChangeNotifier {
  bool _isDisposed = false;
  final taskQueue = AsyncQueue.autoStart(allowDuplicate: true);
  final CancellationToken taskQueueCancelToken = CancellationToken();

  bool isBusy = false;

  bool get isDisposed => _isDisposed;

  BaseViewModel();

  @override
  void dispose() {
    assert(!_isDisposed);
    taskQueueCancelToken.cancel();
    taskQueue.stop();
    taskQueue.close();
    super.dispose();
    _isDisposed = true;
  }

  setBusy(bool value, {bool notify = true}) {
    assert(!_isDisposed);
    isBusy = value;
    if (notify) {
      notifyListeners();
    }
  }

  @override
  void notifyListeners() {
    assert(!_isDisposed);
    super.notifyListeners();
  }
}

mixin ViewModelEventBusMixin on BaseViewModel {
  late final EventBus globalEventBus;

  void notifyAppError(String message, {Object? error, StackTrace? stackTrace}) {
    globalEventBus.fire(
      AppErrorEvent(message, error: error, stackTrace: stackTrace),
    );
  }
}
