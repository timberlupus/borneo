import 'dart:async';
import 'dart:collection';

import 'package:cancellation_token/cancellation_token.dart';

class DeviceCommandQueue {
  final Queue<_QueuedCommand> _queue = Queue();
  _QueuedCommand? _currentCommand;
  bool _isDisposed = false;

  Future<T> enqueue<T>(
    Future<T> Function() command, {
    Duration timeout = const Duration(seconds: 10),
    CancellationToken? cancellationToken,
  }) async {
    if (_isDisposed) {
      throw StateError('DeviceCommandQueue has been disposed');
    }

    final completer = Completer<T>();
    final queuedCommand = _QueuedCommand<T>(
      command: command,
      completer: completer,
      timeout: timeout,
      cancellationToken: cancellationToken,
    );

    _queue.add(queuedCommand);

    if (_currentCommand == null) {
      _processNext();
    }

    return completer.future;
  }

  Future<void> _processNext() async {
    if (_queue.isEmpty || _isDisposed) return;

    _currentCommand = _queue.removeFirst();
    final command = _currentCommand!;

    try {
      final result = await command.command().timeout(command.timeout).asCancellable(command.cancellationToken);

      if (!command.completer.isCompleted) {
        command.completer.complete(result);
      }
    } catch (e) {
      if (!command.completer.isCompleted) {
        command.completer.completeError(e);
      }
    } finally {
      _currentCommand = null;
      if (_queue.isNotEmpty && !_isDisposed) {
        Timer(Duration.zero, _processNext);
      }
    }
  }

  void dispose() {
    _isDisposed = true;

    for (final command in _queue) {
      if (!command.completer.isCompleted) {
        command.completer.completeError(Exception('Device disposed'));
      }
    }
    _queue.clear();

    if (_currentCommand != null && !_currentCommand!.completer.isCompleted) {
      _currentCommand!.completer.completeError(Exception('Device disposed'));
    }
  }
}

class _QueuedCommand<T> {
  final Future<T> Function() command;
  final Completer<T> completer;
  final Duration timeout;
  final CancellationToken? cancellationToken;

  _QueuedCommand({required this.command, required this.completer, required this.timeout, this.cancellationToken});
}
