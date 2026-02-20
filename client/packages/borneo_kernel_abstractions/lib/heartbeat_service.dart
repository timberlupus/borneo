import 'dart:async';

import 'package:borneo_kernel_abstractions/device.dart';

/// Provides heartbeat functionality for bound devices.  The kernel core may
/// suspend or resume the service during bulk operations; individual device
/// strategies (interval, retry, timeout) are maintained per‑device by the
/// implementation.
abstract class HeartbeatService {
  /// Start the heartbeat monitoring process.  Should be called once when the
  /// kernel is started.
  Future<void> start();

  /// Stop the heartbeat process and release any timers.
  Future<void> stop();

  /// Suspend all heartbeat polling; subsequent [resume] will restart them.
  /// This call is idempotent.
  void suspend();

  /// Resume polling after a suspend.  No-op if not suspended.
  void resume();

  /// Called by kernel when a device has been bound; service should begin
  /// monitoring the given device.
  void registerDevice(Device device);

  /// Called by kernel when a device is unbound; service should cease polling.
  void unregisterDevice(String deviceID);

  /// Stream of devices that have timed out or reported a heartbeat failure.
  Stream<Device> get onFailure;

  /// Returns whether the service is currently running (not suspended/stopped).
  bool get isActive;
}
