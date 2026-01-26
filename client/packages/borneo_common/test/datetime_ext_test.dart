import 'package:test/test.dart';
import 'package:borneo_common/datetime_ext.dart';

void main() {
  group('DateTimeMinuteComparison Tests', () {
    test('isEqualToMinute should return true for same minute', () {
      final dt1 = DateTime(2025, 1, 26, 10, 30, 15);
      final dt2 = DateTime(2025, 1, 26, 10, 30, 45);
      expect(dt1.isEqualToMinute(dt2), isTrue);
    });

    test('isEqualToMinute should return false for different minute', () {
      final dt1 = DateTime(2025, 1, 26, 10, 30, 15);
      final dt2 = DateTime(2025, 1, 26, 10, 31, 15);
      expect(dt1.isEqualToMinute(dt2), isFalse);
    });

    test('isEqualToMinute should return false for different hour', () {
      final dt1 = DateTime(2025, 1, 26, 10, 30, 15);
      final dt2 = DateTime(2025, 1, 26, 11, 30, 15);
      expect(dt1.isEqualToMinute(dt2), isFalse);
    });

    test('isEqualToMinute should return false for different day', () {
      final dt1 = DateTime(2025, 1, 26, 10, 30, 15);
      final dt2 = DateTime(2025, 1, 27, 10, 30, 15);
      expect(dt1.isEqualToMinute(dt2), isFalse);
    });

    test('isEqualToSecond should return true for same second', () {
      final dt1 = DateTime(2025, 1, 26, 10, 30, 15, 100);
      final dt2 = DateTime(2025, 1, 26, 10, 30, 15, 500);
      expect(dt1.isEqualToSecond(dt2), isTrue);
    });

    test('isEqualToSecond should return false for different second', () {
      final dt1 = DateTime(2025, 1, 26, 10, 30, 15);
      final dt2 = DateTime(2025, 1, 26, 10, 30, 16);
      expect(dt1.isEqualToSecond(dt2), isFalse);
    });

    test('isEqualToSecond should return false for different minute', () {
      final dt1 = DateTime(2025, 1, 26, 10, 30, 15);
      final dt2 = DateTime(2025, 1, 26, 10, 31, 15);
      expect(dt1.isEqualToSecond(dt2), isFalse);
    });
  });
}
