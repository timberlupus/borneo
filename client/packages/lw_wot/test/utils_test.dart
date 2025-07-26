import 'package:test/test.dart';
import 'package:lw_wot/utils.dart';

void main() {
  group('timestamp', () {
    test('returns ISO8601 string with +00:00', () {
      final ts = timestamp();
      expect(ts, contains('+00:00'));
      expect(DateTime.tryParse(ts.replaceAll('+00:00', 'Z')), isNotNull);
    });
  });
}
