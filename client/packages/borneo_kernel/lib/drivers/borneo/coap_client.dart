import 'dart:io';
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
  });

  @override
  Future<CoapResponse> send(
    final CoapRequest request, {
    final CoapMulticastResponseHandler? onMulticastResponse,
    final CancellationToken? cancellationToken,
  }) async {
    final response = await super
        .send(request, onMulticastResponse: onMulticastResponse)
        .asCancellable(cancellationToken);
    // On successful communication, emit event to reset heartbeat
    if (request.isAcknowledged) {
      deviceEvents?.fire(DeviceCommunicationEvent(device));
    }
    return response;
  }
}
