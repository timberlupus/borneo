import 'package:flutter_test/flutter_test.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';

void main() {
  group('DeviceEntity Basic Tests', () {
    test('create device object', () {
      final device = DeviceEntity(
        id: 'test-001',
        address: Uri.parse('coap://192.168.1.100'),
        fingerprint: 'fp123',
        sceneID: 'scene-1',
        driverID: 'lyfi-driver',
        compatible: '1.0.0',
        name: 'Test LED Light',
        model: 'LYFI-LED',
      );

      expect(device.id, 'test-001');
      expect(device.name, 'Test LED Light');
    });

    test('serialization test', () {
      final device = DeviceEntity(
        id: 'test-002',
        address: Uri.parse('coap://192.168.1.101'),
        fingerprint: 'fp456',
        sceneID: 'scene-1',
        driverID: 'lyfi-driver',
        compatible: '1.0.0',
        name: 'Living Room LED',
        model: 'LYFI-LED',
      );

      final map = device.toMap();
      expect(map['name'], 'Living Room LED');
      expect(map['driverID'], 'lyfi-driver');

      final fromMap = DeviceEntity.fromMap('test-002', map);
      expect(fromMap.name, 'Living Room LED');
    });
  });
}
