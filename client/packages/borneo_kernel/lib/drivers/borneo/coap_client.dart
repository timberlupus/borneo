import 'dart:io';
import 'dart:async';

import 'package:borneo_kernel_abstractions/command_queue.dart';
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
    final CancellationToken? cancellationToken,
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
    }, cancellationToken: cancellationToken);
  }
}
