import 'package:test/test.dart';
import 'package:borneo_common/io/net/rssi.dart';

void main() {
  group('RssiLevel Tests', () {
    test('minRssi should return correct values', () {
      expect(RssiLevel.strong.minRssi, -50);
      expect(RssiLevel.medium.minRssi, -70);
      expect(RssiLevel.weak.minRssi, -90);
    });

    test('fromRssi should return strong for high signal', () {
      expect(RssiLevelExtension.fromRssi(-40), RssiLevel.strong);
      expect(RssiLevelExtension.fromRssi(-50), RssiLevel.strong);
    });

    test('fromRssi should return medium for medium signal', () {
      expect(RssiLevelExtension.fromRssi(-60), RssiLevel.medium);
      expect(RssiLevelExtension.fromRssi(-70), RssiLevel.medium);
    });

    test('fromRssi should return weak for low signal', () {
      expect(RssiLevelExtension.fromRssi(-80), RssiLevel.weak);
      expect(RssiLevelExtension.fromRssi(-90), RssiLevel.weak);
      expect(RssiLevelExtension.fromRssi(-100), RssiLevel.weak);
    });
  });
}
