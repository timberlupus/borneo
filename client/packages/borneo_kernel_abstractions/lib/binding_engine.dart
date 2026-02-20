import 'dart:async';

import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:cancellation_token/cancellation_token.dart';

/// Performs the probe/bind/unbind operations for a single device.  The kernel
/// core will feed descriptors into the engine; the engine is responsible for
/// creating or reusing driver instances and managing the device lifecycle.
abstract class BindingEngine {
  /// All devices currently bound by this engine.  Implementations should keep
  /// this in sync with the results of [bind] and [unbind].
  Iterable<BoundDevice> get boundDevices;

  /// Retrieve a previously bound device.  Returns `null` when the device is
  /// not known or not currently bound.
  BoundDevice? getBoundDevice(String deviceID);

  /// Attempt to probe and bind [device] using driver identified by [driverID].
  /// Returns `true` if the device is successfully bound; errors are caught by
  /// the caller when using [IKernel.tryBind].
  Future<bool> tryBind(Device device, String driverID, {CancellationToken? cancelToken});

  /// Same as [tryBind] but throws on failure.
  Future<void> bind(Device device, String driverID, {CancellationToken? cancelToken});

  /// Unbind the currently bound device.  If the device was not bound this
  /// method must throw or return a future that completes with an error.
  Future<void> unbind(String deviceID, {CancellationToken? cancelToken});

  /// Unbind all currently bound devices.  Default implementations may simply
  /// iterate [boundDevices] and call [unbind].
  Future<void> unbindAll({CancellationToken? cancelToken});

  /// Cancels any ongoing bind/unbind operations and releases internal resources.
  void dispose();

  /// True if a bind or unbind is currently in progress.
  bool get isBusy;
}
