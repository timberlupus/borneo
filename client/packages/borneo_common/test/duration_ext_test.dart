import 'package:test/test.dart';
import 'package:borneo_common/duration_ext.dart';

void main() {
  group('DurationExtension Tests', () {
    test('toHHMM should format duration correctly', () {
      expect(Duration(hours: 2, minutes: 30).toHHMM(), '02:30');
      expect(Duration(hours: 0, minutes: 5).toHHMM(), '00:05');
      expect(Duration(hours: 12, minutes: 45).toHHMM(), '12:45');
      expect(Duration(minutes: 90).toHHMM(), '01:30');
    });

    test('toHH should format hours correctly', () {
      expect(Duration(hours: 2, minutes: 30).toHH(), '02');
      expect(Duration(hours: 0, minutes: 5).toHH(), '00');
      expect(Duration(hours: 12, minutes: 45).toHH(), '12');
      expect(Duration(minutes: 90).toHH(), '01');
      expect(Duration(hours: 25).toHH(), '25');
    });

    test('toHHMMSS should format duration correctly', () {
      expect(Duration(hours: 2, minutes: 30, seconds: 15).toHHMMSS(), '02:30:15');
      expect(Duration(hours: 0, minutes: 5, seconds: 3).toHHMMSS(), '00:05:03');
      expect(Duration(hours: 12, minutes: 45, seconds: 59).toHHMMSS(), '12:45:59');
      expect(Duration(seconds: 3665).toHHMMSS(), '01:01:05');
      expect(Duration(seconds: 59).toHHMMSS(), '00:00:59');
    });
  });
}
