import 'dart:async';

/// Simplified, instance‑based event dispatcher.  Unlike the current
/// `GlobalDevicesEventBus`, implementations should avoid static/global
/// state and expose per‑object streams that callers can subscribe to and
/// dispose of.
abstract class EventDispatcher {
  /// Subscribe to events of type [T].  The returned stream should be
  /// a broadcast stream so multiple listeners can attach.
  Stream<T> on<T>();

  /// Fire an event of any type.  Listeners registered via [on] will
  /// receive the object if their type matches.
  void fire(Object event);

  /// Releases any resources held by the dispatcher.  After calling this
  /// method, [on] streams may complete or throw when listened.
  void destroy();
}
