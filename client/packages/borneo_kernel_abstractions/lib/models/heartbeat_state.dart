/// Represents the tracked heartbeat status of a device.
///
/// This object is returned by [HeartbeatService.getState] and exposes the
/// counters that the kernel or UI may use for diagnostics: how many polling
/// failures have occurred, how many push observations were missed, and the
/// timestamp of the last successful communication (if available).
class HeartbeatState {
  /// number of consecutive poll failures
  final int consecutiveFailures;

  /// number of missed push observations (if using push‑mode)
  final int missedObservations;

  /// most recent successful communication time
  final DateTime? lastSeen;

  const HeartbeatState({this.consecutiveFailures = 0, this.missedObservations = 0, this.lastSeen});

  HeartbeatState copyWith({int? consecutiveFailures, int? missedObservations, DateTime? lastSeen}) {
    return HeartbeatState(
      consecutiveFailures: consecutiveFailures ?? this.consecutiveFailures,
      missedObservations: missedObservations ?? this.missedObservations,
      lastSeen: lastSeen ?? this.lastSeen,
    );
  }
}
