import 'dart:async';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/services.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:logger/logger.dart';

abstract class IBleProvisioner {
  Future<List<String>> scanBleDevices(String prefix, {CancellationToken? cancelToken});
  Future<List<WifiNetwork>> scanWifiNetworks(String deviceName, {String pop = '', CancellationToken? cancelToken});
  Future<void> provisionWifi(String deviceName, String ssid, String password, {CancellationToken? cancelToken});
}

class BleProvisioner implements IBleProvisioner {
  final _plugin = FlutterEspBleProv();
  final Logger _logger = Logger();

  @override
  Future<List<String>> scanBleDevices(String prefix, {CancellationToken? cancelToken}) async {
    try {
      // The scanBleDevices returns List<String> which are device names properly prefixed.
      final devices = await _plugin.scanBleDevices(prefix).asCancellable(cancelToken);
      return devices;
    } on PlatformException catch (e) {
      _logger.e('PlatformException during BLE scan: ${e.code}', error: e);
      return [];
    } catch (e) {
      _logger.e('Error scanning BLE devices', error: e);
      return [];
    }
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
    try {
      await _plugin.provisionWifi(deviceName, '', ssid, password).asCancellable(cancelToken);
    } catch (e) {
      _logger.e('Error provisioning WiFi', error: e);
      rethrow;
    }
  }
}
