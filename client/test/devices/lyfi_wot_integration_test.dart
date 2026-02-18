import 'package:borneo_app/devices/borneo/lyfi/manifest.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LyfiThing Integration Tests', () {
    late DeviceEntity testDevice;

    setUp(() {
      testDevice = DeviceEntity(
        id: 'test-lyfi-device',
        name: 'Test LyFi Device',
        driverID: 'borneo-lyfi',
        sceneID: 'test-scene',
        fingerprint: 'test-fingerprint',
        address: Uri.parse('coap://192.168.1.100:5683'),
        compatible: 'test-compatible',
        model: 'test-model',
      );
    });

    test('should create metadata instance', () {
      // Act
      final metadata = LyfiDeviceModuleMetadata();

      // Assert
      expect(metadata, isNotNull);
      expect(metadata.id, isNotEmpty);
      expect(metadata.name, isNotEmpty);
    });

    test('should have valid device entity properties', () {
      // Assert
      expect(testDevice.id, equals('test-lyfi-device'));
      expect(testDevice.name, equals('Test LyFi Device'));
      expect(testDevice.driverID, equals('borneo-lyfi'));
      expect(testDevice.sceneID, equals('test-scene'));
      expect(testDevice.fingerprint, equals('test-fingerprint'));
      expect(testDevice.address.toString(), equals('coap://192.168.1.100:5683'));
      expect(testDevice.compatible, equals('test-compatible'));
      expect(testDevice.model, equals('test-model'));
    });
  });
}
