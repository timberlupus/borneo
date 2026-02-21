import 'dart:async';

import 'package:borneo_kernel_abstractions/models/discovered_device.dart';

/// Represents a communication bus (mDNS, BLE, CoAP, etc.) that can discover
/// devices and produce connection handles.  This interface is derived from
/// the design notes in `.design-docs/bus-design.md`.
abstract class DeviceBus {
  /// Identifier for the bus type (e.g. "mdns", "ble").
  String get id;

  /// Begin scanning or listening on this bus.
  Future<void> start();

  /// Halt discovery on this bus.
  Future<void> stop();

  /// Stream that emits a [DiscoveredDevice] when one is found.
  Stream<DiscoveredDevice> get onDeviceFound;

  /// Stream emitting the ID of a device that was lost.
  Stream<String> get onDeviceLost;

  /// Obtain a connection handle for the specified device.
  Future<dynamic> connect(String deviceId);

  /// Disconnect and release a previously obtained handle.
  Future<void> disconnect(String deviceId);
}
