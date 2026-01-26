import 'package:test/test.dart';
import 'package:borneo_common/exceptions.dart';

void main() {
  group('Exception Tests', () {
    test('PermissionDeniedException should return correct message', () {
      final exception = PermissionDeniedException(message: 'Access denied');
      expect(exception.toString(), 'PermissionDeniedException: Access denied');
    });

    test('InvalidDataException should return correct message', () {
      final exception = InvalidDataException(message: 'Data is invalid');
      expect(exception.toString(), 'InvalidDataException: Data is invalid');
    });

    test('InvalidOperationException should return correct message', () {
      final exception = InvalidOperationException(message: 'Operation not allowed');
      expect(exception.toString(), 'InvalidOperationException: Operation not allowed');
    });

    test('FileNotFoundException should return correct path and message', () {
      final exception = FileNotFoundException(path: '/path/to/file', message: 'File not found');
      expect(exception.path, '/path/to/file');
      expect(exception.message, 'File not found');
    });

    test('ObjectDisposedException should have correct message', () {
      final exception = ObjectDisposedException(message: 'Object has been disposed');
      expect(exception.message, 'Object has been disposed');
    });

    test('KeyNotFoundException should have correct message and key', () {
      final exception = KeyNotFoundException(message: 'Key not found', key: 'testKey');
      expect(exception.message, 'Key not found');
      expect(exception.key, 'testKey');
    });

    test('KeyNotFoundException with default values', () {
      final exception = KeyNotFoundException();
      expect(exception.message, '');
      expect(exception.key, isNull);
    });
  });
}
