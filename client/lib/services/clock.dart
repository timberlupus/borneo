abstract class IClock {
  DateTime now();
  DateTime utcNow();
}

final class DefaultClock implements IClock {
  @override
  DateTime now() => DateTime.now();

  @override
  DateTime utcNow() => DateTime.timestamp();
}
