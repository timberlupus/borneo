import 'dart:async';
import 'package:cancellation_token/cancellation_token.dart';

typedef AsyncTask = Future Function();

class AsyncRateLimiter {
  final CancellationToken _cancel = CancellationToken();
  final Duration interval;
  final StreamController<AsyncTask> _controller = StreamController<AsyncTask>.broadcast();
  DateTime? _lastExecutionTime;
  AsyncTask? _pendingValue;
  bool _isExecuting = false;

  AsyncRateLimiter({required this.interval}) {
    _controller.stream.listen((value) async {
      _pendingValue = value;
      await _processQueue();
    });

    _controller.done.then((_) async {
      if (_cancel.isCancelled) return;
      try {
        await _executeLastPendingValue().asCancellable(_cancel);
      } on CancelledException {
        return;
      }
    });
  }

  Stream<AsyncTask> get stream => _controller.stream;

  void add(AsyncTask value) {
    _controller.add(value);
  }

  Future<void> _processQueue() async {
    if (_isExecuting) return;

    _isExecuting = true;
    try {
      while (_pendingValue != null && !_cancel.isCancelled) {
        final now = DateTime.now();
        if (_lastExecutionTime == null || now.difference(_lastExecutionTime!) >= interval) {
          _lastExecutionTime = now;
          final valueToExecute = _pendingValue;
          _pendingValue = null;
          try {
            await _executeTask(valueToExecute!).asCancellable(_cancel);
          } on CancelledException {
            return;
          }
          continue;
        }

        final remaining = interval - now.difference(_lastExecutionTime!);
        if (remaining > Duration.zero) {
          await Future.delayed(remaining);
        }
      }
    } finally {
      _isExecuting = false;
    }
  }

  Future<void> _executeLastPendingValue() async {
    if (_pendingValue != null && !_cancel.isCancelled) {
      await _executeTask(_pendingValue!);
      _pendingValue = null;
    }
  }

  Future<void> _executeTask(AsyncTask task) async {
    await task();
  }

  void dispose() {
    _cancel.cancel();
    _controller.close();
  }
}
