import 'dart:async';

import 'package:borneo_kernel_abstractions/models/discovered_device.dart';

/// Manages the discovery portion of the kernel.  A concrete implementation
/// aggregates one or more [DeviceBus] instances and exposes a unified stream
/// of discovered devices.
abstract class DiscoveryManager {
  /// Starts discovery.  Subsequent calls are no‑ops until [stop] is invoked.
  Future<void> start({Duration? timeout});

  /// Stops any in‑progress discovery operation.
  Future<void> stop();

  /// Stream that fires whenever a new device is discovered.
  Stream<DiscoveredDevice> get onDeviceFound;

  /// Indicates whether discovery is currently active.
  bool get isActive;
}
