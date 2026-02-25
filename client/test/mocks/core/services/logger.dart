import 'package:logger/logger.dart';

/// Simple logger that records messages for verification in tests.
class TestLogger implements Logger {
  final List<String> messages = [];

  @override
  void v(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('V: $message');
  }

  @override
  void d(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('D: $message');
  }

  @override
  void i(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('I: $message');
  }

  @override
  void w(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('W: $message');
  }

  @override
  void e(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('E: $message');
  }

  @override
  void wtf(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('WTF: $message');
  }

  @override
  void log(Level level, dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('${level.name}: $message');
  }

  @override
  bool isClosed() => false;

  @override
  Future<void> close() async {}

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
