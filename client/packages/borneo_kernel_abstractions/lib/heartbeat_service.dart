import 'dart:async';

import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';

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
  /// monitoring the given bound device.  The caller provides the
  /// [HeartbeatMethod] that the driver prefers (poll or push) so the
  /// implementation can choose the appropriate strategy.
  void registerDevice(BoundDevice bound, HeartbeatMethod method);

  /// Called by kernel when a previously monitored device is removed.  The
  /// service should stop any polling/observation and free associated state.
  void unregisterDevice(String deviceID);

  /// Notifies the service that normal device communication occurred.  This
  /// is used primarily by push‑based drivers to reset missing‑heartbeat
  /// counters when the device talks to the kernel for reasons other than a
  /// heartbeat event.
  void onDeviceCommunication(String deviceID);

  /// Stream of devices that have timed out or reported a heartbeat failure.
  Stream<Device> get onFailure;

  /// Emits a signal each time the internal polling timer fires.  This allows
  /// external callers (e.g. the kernel) to perform auxiliary work such as
  /// trying to bind unbound devices.
  Stream<void> get onTick;

  /// Returns whether the service is currently running (not suspended/stopped).
  bool get isActive;
}
