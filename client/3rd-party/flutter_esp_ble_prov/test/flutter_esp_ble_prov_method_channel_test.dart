import 'package:flutter/services.dart';
import 'package:flutter_esp_ble_prov/src/flutter_esp_ble_prov_method_channel.dart';
import 'package:flutter_esp_ble_prov/src/security_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  MethodChannelFlutterEspBleProv platform = MethodChannelFlutterEspBleProv();
  const MethodChannel channel = MethodChannel('flutter_esp_ble_prov');

  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          return '42';
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('getPlatformVersion', () async {
    expect(await platform.getPlatformVersion(), '42');
  });

  test('scanWifiNetworksWithDetails', () async {
    // Mock the method call handler for scanWifiNetworksWithDetails
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (MethodCall methodCall) async {
          if (methodCall.method == 'scanWifiNetworksWithDetails') {
            return [
              {'ssid': 'TestNetwork1', 'rssi': -45, 'security': 1},
              {'ssid': 'TestNetwork2', 'rssi': -67, 'security': 0},
            ];
          }
          return '42';
        });

    final networks = await platform.scanWifiNetworksWithDetails(
      'TestDevice',
      'test123',
      SecurityLevel.unsecure,
    );

    expect(networks.length, 2);
    expect(networks[0].ssid, 'TestNetwork1');
    expect(networks[0].rssi, -45);
    expect(networks[0].security, 1);
    expect(networks[1].ssid, 'TestNetwork2');
    expect(networks[1].rssi, -67);
    expect(networks[1].security, 0);
  });
}
