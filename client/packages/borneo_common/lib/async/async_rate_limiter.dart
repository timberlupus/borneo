import 'dart:async';
import 'package:cancellation_token/cancellation_token.dart';

class AsyncRateLimiter<T> {
  final CancellationToken _cancel = CancellationToken();
  final Duration interval;
  final StreamController<T> _controller = StreamController<T>.broadcast();
  DateTime? _lastExecutionTime;
  T? _pendingValue;
  bool _isExecuting = false;

  AsyncRateLimiter({required this.interval}) {
    _controller.stream.listen((value) async {
      _pendingValue = value;
      await _processQueue();
    });

    _controller.done.then((_) async {
      await _executeLastPendingValue().asCancellable(_cancel);
    });
  }

  Stream<T> get stream => _controller.stream;

  void add(T value) {
    _controller.add(value);
  }

  Future<void> _processQueue() async {
    if (_isExecuting) return;

    _isExecuting = true;
    while (_pendingValue != null && !_cancel.isCancelled) {
      final now = DateTime.now();
      if (_lastExecutionTime == null || now.difference(_lastExecutionTime!) >= interval) {
        _lastExecutionTime = now;
        final valueToExecute = _pendingValue;
        _pendingValue = null; // Clear pending value before executing
        await _executeTask(valueToExecute as T);
      }
      await Future.delayed(interval); // Ensures interval between executions
    }
    _isExecuting = false;
  }

  Future<void> _executeLastPendingValue() async {
    if (_pendingValue != null) {
      await _executeTask(_pendingValue as T);
      _pendingValue = null;
    }
  }

  Future<void> _executeTask(T task) async {
    if (task is Future Function()) {
      await task();
    } else {
      throw ArgumentError('Task must be a Future Function()');
    }
  }

  void dispose() {
    if (_isExecuting) {
      _cancel.cancel();
    }
    _controller.close();
  }
}
