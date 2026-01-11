import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'flutter_esp_ble_prov_platform_interface.dart';
import 'wifi_network.dart';

/// An implementation of [FlutterEspBleProvPlatform] that uses method channels.
class MethodChannelFlutterEspBleProv extends FlutterEspBleProvPlatform {
  /// The method channel used to interact with the native platform.
  @visibleForTesting
  final methodChannel = const MethodChannel('flutter_esp_ble_prov');

  @override
  Future<String?> getPlatformVersion() async {
    final version = await methodChannel.invokeMethod<String>(
      'getPlatformVersion',
    );
    return version;
  }

  @override
  Future<List<String>> scanBleDevices(String prefix) async {
    final args = {'prefix': prefix};
    final raw = await methodChannel.invokeMethod<List<Object?>>(
      'scanBleDevices',
      args,
    );
    final List<String> devices = [];
    if (raw != null) {
      devices.addAll(raw.cast<String>());
    }
    return devices;
  }

  @override
  Future<List<String>> scanWifiNetworks(
    String deviceName,
    String proofOfPossession,
  ) async {
    final args = {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
    };
    final raw = await methodChannel.invokeMethod<List<Object?>>(
      'scanWifiNetworks',
      args,
    );
    final List<String> networks = [];
    if (raw != null) {
      networks.addAll(raw.cast<String>());
    }
    return networks;
  }

  @override
  Future<List<WifiNetwork>> scanWifiNetworksWithDetails(
    String deviceName,
    String proofOfPossession,
  ) async {
    final args = {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
    };
    final raw = await methodChannel.invokeMethod<List<Object?>>(
      'scanWifiNetworksWithDetails',
      args,
    );
    final List<WifiNetwork> networks = [];
    if (raw != null) {
      networks.addAll(
        raw.map((item) {
          if (item is Map<Object?, Object?>) {
            // Convert Map<Object?, Object?> to Map<String, dynamic>
            final map = <String, dynamic>{};
            item.forEach((key, value) {
              if (key is String) {
                map[key] = value;
              }
            });
            return WifiNetwork.fromJson(map);
          }
          throw FormatException('Invalid data format: $item');
        }),
      );
    }
    return networks;
  }

  @override
  Future<bool?> provisionWifi(
    String deviceName,
    String proofOfPossession,
    String ssid,
    String passphrase,
  ) async {
    final args = {
      'deviceName': deviceName,
      'proofOfPossession': proofOfPossession,
      'ssid': ssid,
      'passphrase': passphrase,
    };
    return await methodChannel.invokeMethod<bool?>('provisionWifi', args);
  }
}
