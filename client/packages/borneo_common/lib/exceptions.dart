import 'dart:io';

class PermissionDeniedException implements Exception {
  final String message;

  PermissionDeniedException(this.message);

  @override
  String toString() => 'PermissionDeniedException: $message';
}

class InvalidOperationException implements Exception {
  final String message;

  InvalidOperationException({this.message = ''});

  @override
  String toString() => 'InvalidOperationException: $message';
}

class FileNotFoundException implements IOException {
  final String path;
  const FileNotFoundException(this.path);
}

class ObjectDisposedException implements Exception {
  final String message;
  const ObjectDisposedException(this.message);
}

class KeyNotFoundException implements Exception {
  final String message;
  final Object? key;
  const KeyNotFoundException(this.message, {this.key});
}
