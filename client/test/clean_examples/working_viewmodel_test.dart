import 'package:flutter_test/flutter_test.dart';

// Simple ViewModel test example
class SimpleDeviceManager {
  final List<String> _devices = [];
  bool _isScanning = false;

  List<String> get devices => List.unmodifiable(_devices);
  bool get isScanning => _isScanning;

  void addDevice(String deviceId) {
    if (!_devices.contains(deviceId)) {
      _devices.add(deviceId);
    }
  }

  void removeDevice(String deviceId) {
    _devices.remove(deviceId);
  }

  Future<void> scanDevices() async {
    _isScanning = true;
    await Future.delayed(const Duration(milliseconds: 100));
    _devices.addAll(['device-001', 'device-002', 'device-003']);
    _isScanning = false;
  }

  void clearDevices() {
    _devices.clear();
  }
}

void main() {
  group('ViewModel Test Examples', () {
    late SimpleDeviceManager manager;

    setUp(() {
      manager = SimpleDeviceManager();
    });

    test('Initial state', () {
      expect(manager.devices, isEmpty);
      expect(manager.isScanning, false);
    });

    test('Add device', () {
      manager.addDevice('test-device');
      expect(manager.devices, contains('test-device'));
      expect(manager.devices.length, 1);
    });

    test('Remove device', () {
      manager.addDevice('device-to-remove');
      expect(manager.devices.length, 1);

      manager.removeDevice('device-to-remove');
      expect(manager.devices, isEmpty);
    });

    test('Async scanning', () async {
      expect(manager.isScanning, false);

      final future = manager.scanDevices();
      expect(manager.isScanning, true);

      await future;
      expect(manager.isScanning, false);
      expect(manager.devices.length, 3);
    });

    test('Clear devices', () {
      manager.addDevice('device-1');
      manager.addDevice('device-2');
      expect(manager.devices.length, 2);

      manager.clearDevices();
      expect(manager.devices, isEmpty);
    });
  });
}
