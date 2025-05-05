import 'dart:io';

class PermissionDeniedException implements Exception {
  final String message;

  PermissionDeniedException({this.message = ''});

  @override
  String toString() => 'PermissionDeniedException: $message';
}

class InvalidDataException implements Exception {
  final String message;

  InvalidDataException({this.message = ''});

  @override
  String toString() => 'InvalidDataException: $message';
}

class InvalidOperationException implements Exception {
  final String message;

  InvalidOperationException({this.message = ''});

  @override
  String toString() => 'InvalidOperationException: $message';
}

class FileNotFoundException implements IOException {
  final String path;
  final String message;
  const FileNotFoundException({required this.path, this.message = ''});
}

class ObjectDisposedException implements Exception {
  final String message;
  const ObjectDisposedException({this.message = ''});
}

class KeyNotFoundException implements Exception {
  final String message;
  final Object? key;
  const KeyNotFoundException({this.message = '', this.key});
}
