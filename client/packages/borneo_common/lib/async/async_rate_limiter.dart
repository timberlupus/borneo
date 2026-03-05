import 'dart:async';
import 'dart:collection';
import 'package:cancellation_token/cancellation_token.dart';

typedef AsyncTask = Future Function();

/// A simple rate limiter that ensures asynchronous tasks are executed no faster
/// than the provided [interval]. Tasks are enqueued and processed in FIFO order.
class AsyncRateLimiter {
  /// Minimum time between task executions.
  final Duration interval;

  /// When true the limiter behaves like a combined throttle+debounce: if a task
  /// is added while another is pending the earlier task is dropped and only the
  /// latest one will eventually be executed.
  final bool keepLatest;

  final CancellationToken _cancel = CancellationToken();

  // queue holds tasks waiting to be executed in the normal mode.  When
  // [keepLatest] is enabled we ignore the queue and instead track a single
  // pending task in [_pendingTask].
  final Queue<AsyncTask> _queue = Queue<AsyncTask>();
  AsyncTask? _pendingTask;

  DateTime? _lastExecutionTime;
  bool _isProcessing = false;

  AsyncRateLimiter({required this.interval, this.keepLatest = false});

  /// Enqueues a new task.  In normal mode it is appended to the queue.  In
  /// [keepLatest] mode any existing pending task (not yet executed) is replaced
  /// by [task].
  void add(AsyncTask task) {
    if (keepLatest) {
      _pendingTask = task;
    } else {
      _queue.add(task);
    }
    _processQueue();
  }

  Future<void> _processQueue() async {
    if (_isProcessing) return;
    _isProcessing = true;

    try {
      if (keepLatest) {
        // operate on the single pending task
        while (_pendingTask != null && !_cancel.isCancelled) {
          final now = DateTime.now();
          if (_lastExecutionTime == null || now.difference(_lastExecutionTime!) >= interval) {
            _lastExecutionTime = now;
            final task = _pendingTask;
            _pendingTask = null;
            try {
              await task!().asCancellable(_cancel);
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
      } else {
        while (_queue.isNotEmpty && !_cancel.isCancelled) {
          final now = DateTime.now();
          if (_lastExecutionTime == null || now.difference(_lastExecutionTime!) >= interval) {
            _lastExecutionTime = now;
            final task = _queue.removeFirst();
            try {
              await task().asCancellable(_cancel);
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
      }
    } finally {
      _isProcessing = false;
    }
  }

  void dispose() {
    _cancel.cancel();
    _queue.clear();
  }
}
