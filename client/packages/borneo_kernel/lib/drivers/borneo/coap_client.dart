import 'dart:io';
import 'dart:collection';
import 'dart:async';

import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:coap/coap.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';

class BorneoCoapClient extends CoapClient {
  Logger? logger;
  Device device;
  EventBus? deviceEvents;
  bool offlineDetectionEnabled = true;
  final DeviceCommandQueue _commandQueue;

  BorneoCoapClient(
    super.baseUri, {
    super.addressType = InternetAddressType.any,
    super.bindAddress,
    super.pskCredentialsCallback,
    super.config,
    required this.device,
    this.deviceEvents,
    this.offlineDetectionEnabled = true,
    this.logger,
  }) : _commandQueue = DeviceCommandQueue();

  @override
  void close() {
    _commandQueue.dispose();
    super.close();
  }

  @override
  Future<CoapResponse> send(
    final CoapRequest request, {
    final CoapMulticastResponseHandler? onMulticastResponse,
  }) async {
    return _commandQueue.enqueue(() async {
      try {
        return await super.send(request);
      } on IOException {
        if (offlineDetectionEnabled && deviceEvents != null) {
          // Emit an event to notify that the device is offline
          if (logger != null) {
            logger!.w('Device ${device.id} is offline. Emitting DeviceOfflineEvent.');
          }
          deviceEvents!.fire(DeviceOfflineEvent(device));
        }
        rethrow;
      }
    });
  }

  // 支持超时和取消的send方法
  Future<CoapResponse> sendWithTimeout(
    final CoapRequest request, {
    final Duration timeout = const Duration(seconds: 10),
    final CancellationToken? cancellationToken,
    final CoapMulticastResponseHandler? onMulticastResponse,
  }) async {
    return _commandQueue.enqueue(
      () async {
        try {
          final response = await super
              .send(request)
              .timeout(timeout, onTimeout: () => throw TimeoutException('Device operation timed out', timeout));
          return response;
        } on IOException {
          if (offlineDetectionEnabled && deviceEvents != null) {
            if (logger != null) {
              logger!.w('Device ${device.id} is offline. Emitting DeviceOfflineEvent.');
            }
            deviceEvents!.fire(DeviceOfflineEvent(device));
          }
          rethrow;
        }
      },
      timeout: timeout,
      cancellationToken: cancellationToken,
    );
  }
}

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
