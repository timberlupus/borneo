import 'package:test/test.dart';
import 'package:borneo_common/utils/float.dart';

double _maxFloat32() => 3.4e38;

double _minFloat32() => -3.4e38;

void main() {
  group('convertToFloat32', () {
    test('should return the same value for normal float', () {
      expect(convertToFloat32(1.23), closeTo(1.23, 1e-6));
    });
  });

  group('isValidFloat32', () {
    test('should return true for valid float32', () {
      expect(isValidFloat32(1.0), isTrue);
      expect(isValidFloat32(_maxFloat32()), isTrue);
      expect(isValidFloat32(_minFloat32()), isTrue);
    });
    test('should return false for NaN and infinity', () {
      expect(isValidFloat32(double.nan), isFalse);
      expect(isValidFloat32(double.infinity), isFalse);
      expect(isValidFloat32(double.negativeInfinity), isFalse);
    });
    test('should return false for value out of float32 range', () {
      expect(isValidFloat32(1e39), isFalse);
      expect(isValidFloat32(-1e39), isFalse);
    });
  });
}
