import 'dart:async';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';

abstract class IBleProvisioner {
  Future<List<String>> scanBleDevices(String prefix, {CancellationToken? cancelToken});
  Future<List<WifiNetwork>> scanWifiNetworks(String deviceName, {String pop = '', CancellationToken? cancelToken});
  Future<void> provisionWifi(String deviceName, String ssid, String password, {CancellationToken? cancelToken});
}

class BleProvisioner implements IBleProvisioner {
  final _plugin = FlutterEspBleProv();

  BleProvisioner();

  @override
  Future<List<String>> scanBleDevices(String prefix, {CancellationToken? cancelToken}) async {
    // The scanBleDevices returns List<String> which are device names properly prefixed.
    final devices = await _plugin.scanBleDevices(prefix).asCancellable(cancelToken);
    return devices;
  }

  @override
  Future<List<WifiNetwork>> scanWifiNetworks(
    String deviceName, {
    String pop = '',
    CancellationToken? cancelToken,
  }) async {
    // According to documentation, this returns List<String> of SSIDs.
    // We pass empty string as proofOfPossession for devices without PoP.
    return await _plugin.scanWifiNetworksWithDetails(deviceName, pop).asCancellable(cancelToken);
  }

  @override
  Future<void> provisionWifi(String deviceName, String ssid, String password, {CancellationToken? cancelToken}) async {
    final result = await _plugin.provisionWifi(deviceName, '', ssid, password).asCancellable(cancelToken);
    if (result != true) {
      throw StateError('Provisioning failed');
    }
  }
}
