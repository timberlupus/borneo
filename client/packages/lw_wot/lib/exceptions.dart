// Dart port of src/exceptions.ts

class WotException implements Exception {
  final String message;

  WotException(this.message);

  @override
  String toString() => 'WotException: $message';
}

class InvalidOperationException extends WotException {
  InvalidOperationException({String message = ''}) : super(message);
}
