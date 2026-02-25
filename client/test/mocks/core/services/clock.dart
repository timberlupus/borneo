import 'package:borneo_app/core/services/clock.dart';

/// Simple clock that forwards to ``DateTime.now()``.  Used in many tests.
class TestClock implements IClock {
  @override
  DateTime now() => DateTime.now();

  @override
  DateTime utcNow() => DateTime.now().toUtc();
}
