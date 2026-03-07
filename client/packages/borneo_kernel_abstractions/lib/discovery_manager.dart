import 'dart:async';

import 'package:borneo_common/borneo_common.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';
import 'package:borneo_kernel_abstractions/device_bus.dart';

/// Manages the discovery portion of the kernel.  A concrete implementation
/// aggregates one or more [DeviceBus] instances and exposes a unified stream
/// of discovered devices.  Buses may be added or removed dynamically.
abstract class DiscoveryManager implements IDisposable {
  /// Starts discovery.  Subsequent calls are no‑ops until [stop] is invoked.
  ///
  /// [timeout] will automatically stop discovery after the duration elapses
  /// unless a cancellation token is triggered first.
  Future<void> start({Duration? timeout, CancellationToken? cancelToken});

  /// Stops any in‑progress discovery operation.  The returned future completes
  /// once all buses have been halted.  A [cancelToken] may be provided for
  /// cooperative cancellation.
  Future<void> stop({CancellationToken? cancelToken});

  /// Stream that fires whenever a new device is discovered.
  Stream<DiscoveredDevice> get onDeviceFound;

  /// Stream that emits a [DiscoveredDevice] that a bus reports as lost.
  Stream<DiscoveredDevice> get onDeviceLost;

  /// Indicates whether discovery is currently active.
  bool get isActive;

  /// Add a [DeviceBus] to be managed.  If discovery is already running, the
  /// bus will be started immediately.
  void registerBus(DeviceBus bus);

  /// Remove a previously registered bus.  If discovery is running the bus will
  /// be stopped.
  void unregisterBus(String busId);
}
