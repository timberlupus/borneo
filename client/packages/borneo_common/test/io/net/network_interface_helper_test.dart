import 'package:test/test.dart';
import 'package:borneo_common/io/net/network_interface_helper.dart';

void main() {
  group('NetworkInterfaceHelper Tests', () {
    test('inferNetworkInterface should return null for invalid IP', () async {
      final result = await NetworkInterfaceHelper.inferNetworkInterface('invalid-ip');
      expect(result, isNull);
    });

    test('inferNetworkInterface should work with valid IPv4', () async {
      // This test may return null or a valid interface depending on the system
      final result = await NetworkInterfaceHelper.inferNetworkInterface('192.168.1.100');
      // We just check that it doesn't throw an error
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('inferNetworkInterface should work with valid IPv6', () async {
      // Test IPv6 address
      final result = await NetworkInterfaceHelper.inferNetworkInterface('fe80::1');
      expect(result, anyOf(isNull, isA<String>()));
    });

    test('inferNetworkInterface should handle empty string', () async {
      expect(await NetworkInterfaceHelper.inferNetworkInterface(''), isNull);
    });

    test('inferNetworkInterface should handle invalid IPv4', () async {
      expect(await NetworkInterfaceHelper.inferNetworkInterface('999.999.999.999'), isNull);
    });

    test('inferNetworkInterface should handle malformed IPv4', () async {
      expect(await NetworkInterfaceHelper.inferNetworkInterface('192.168.1'), isNull);
      expect(await NetworkInterfaceHelper.inferNetworkInterface('192.168.1.1.1'), isNull);
    });
  });
}
