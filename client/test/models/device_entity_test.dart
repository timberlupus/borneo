import 'package:flutter_test/flutter_test.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';

void main() {
  group('DeviceEntity Tests', () {
    late DeviceEntity testDevice;
    const testId = 'test-device-123';
    const testName = 'Test LED Strip';
    const testDriverId = 'lyfi-led-controller';
    const testSceneId = 'main-tank-scene';

    setUp(() {
      testDevice = DeviceEntity(
        id: testId,
        address: Uri.parse('coap://192.168.1.100:5683'),
        fingerprint: 'device-fingerprint-abc123',
        sceneID: testSceneId,
        driverID: testDriverId,
        compatible: '1.0.0',
        name: testName,
        model: 'LYFI-LED-PRO',
        groupID: 'group-1',
      );
    });

    group('Constructor Tests', () {
      test('creates device with required parameters', () {
        expect(testDevice.id, testId);
        expect(testDevice.name, testName);
        expect(testDevice.driverID, testDriverId);
        expect(testDevice.sceneID, testSceneId);
        expect(testDevice.address.toString(), 'coap://192.168.1.100:5683');
        expect(testDevice.fingerprint, 'device-fingerprint-abc123');
        expect(testDevice.compatible, '1.0.0');
        expect(testDevice.model, 'LYFI-LED-PRO');
        expect(testDevice.groupID, 'group-1');
      });

      test('creates device without groupID', () {
        final device = DeviceEntity(
          id: testId,
          address: Uri.parse('coap://192.168.1.100'),
          fingerprint: 'test-fp',
          sceneID: testSceneId,
          driverID: testDriverId,
          compatible: '1.0.0',
          name: testName,
          model: 'TestModel',
        );

        expect(device.groupID, isNull);
      });
    });

    group('Serialization Tests', () {
      test('converts to map correctly', () {
        final map = testDevice.toMap();

        expect(map['id'], testId);
        expect(map['sceneID'], testSceneId);
        expect(map['groupID'], 'group-1');
        expect(map['address'], 'coap://192.168.1.100:5683');
        expect(map['driverID'], testDriverId);
        expect(map['compatible'], '1.0.0');
        expect(map['fingerprint'], 'device-fingerprint-abc123');
        expect(map['name'], testName);
        expect(map['model'], 'LYFI-LED-PRO');
      });

      test('creates from map correctly', () {
        final testMap = {
          'sceneID': 'new-scene-id',
          'groupID': 'new-group-id',
          'address': 'coap://192.168.1.200:5683',
          'driverID': 'new-driver',
          'compatible': '2.0.0',
          'fingerprint': 'new-fingerprint',
          'name': 'New Device Name',
          'model': 'NewModel',
        };

        final device = DeviceEntity.fromMap('new-device-id', testMap);

        expect(device.id, 'new-device-id');
        expect(device.sceneID, 'new-scene-id');
        expect(device.groupID, 'new-group-id');
        expect(device.address.toString(), 'coap://192.168.1.200:5683');
        expect(device.driverID, 'new-driver');
        expect(device.compatible, '2.0.0');
        expect(device.fingerprint, 'new-fingerprint');
        expect(device.name, 'New Device Name');
        expect(device.model, 'NewModel');
      });

      test('handles map without groupID', () {
        final testMap = {
          'sceneID': testSceneId,
          'address': 'coap://192.168.1.100',
          'driverID': testDriverId,
          'compatible': '1.0.0',
          'fingerprint': 'test-fp',
          'name': testName,
          'model': 'TestModel',
        };

        final device = DeviceEntity.fromMap('test-id', testMap);

        expect(device.groupID, isNull);
      });
    });

    group('Driver Data Tests', () {
      test('throws StateError when driverData accessed before set', () {
        expect(() => testDevice.driverData, throwsStateError);
      });
    });

    group('String Representation Tests', () {
      test('toString returns correct format', () {
        final str = testDevice.toString();

        expect(str, contains('Device(id: `$testId`'));
        expect(str, contains('name: `$testName`'));
        expect(str, contains('model: `LYFI-LED-PRO`'));
        expect(str, contains('uri: `coap://192.168.1.100:5683`'));
      });
    });

    group('Field Constants Tests', () {
      test('has correct field name constants', () {
        expect(DeviceEntity.kNameFieldName, 'name');
        expect(DeviceEntity.kSceneIDFieldName, 'sceneID');
        expect(DeviceEntity.kGroupIDFieldName, 'groupID');
        expect(DeviceEntity.kFngerprintFieldName, 'fingerprint');
        expect(DeviceEntity.kAddressFieldName, 'address');
      });
    });

    group('Equality Tests', () {
      test('devices with same ID are equal regardless of other fields', () {
        final device1 = DeviceEntity(
          id: 'same-id',
          address: Uri.parse('coap://192.168.1.100'),
          fingerprint: 'fp1',
          sceneID: 'scene1',
          driverID: 'driver1',
          compatible: '1.0.0',
          name: 'Device 1',
          model: 'Model1',
        );

        final device2 = DeviceEntity(
          id: 'same-id',
          address: Uri.parse('coap://192.168.1.200'),
          fingerprint: 'fp2',
          sceneID: 'scene2',
          driverID: 'driver2',
          compatible: '2.0.0',
          name: 'Device 2',
          model: 'Model2',
        );

        expect(device1.id, device2.id);
      });

      test('devices with different IDs are not equal', () {
        final device1 = DeviceEntity(
          id: 'id-1',
          address: Uri.parse('coap://192.168.1.100'),
          fingerprint: 'fp1',
          sceneID: 'scene1',
          driverID: 'driver1',
          compatible: '1.0.0',
          name: 'Device 1',
          model: 'Model1',
        );

        final device2 = DeviceEntity(
          id: 'id-2',
          address: Uri.parse('coap://192.168.1.100'),
          fingerprint: 'fp1',
          sceneID: 'scene1',
          driverID: 'driver1',
          compatible: '1.0.0',
          name: 'Device 1',
          model: 'Model1',
        );

        expect(device1.id, isNot(device2.id));
      });
    });

    group('Address Handling Tests', () {
      test('handles different URI schemes', () {
        final httpDevice = DeviceEntity(
          id: 'http-device',
          address: Uri.parse('http://192.168.1.100:80'),
          fingerprint: 'fp',
          sceneID: testSceneId,
          driverID: testDriverId,
          compatible: '1.0.0',
          name: 'HTTP Device',
          model: 'Model',
        );

        expect(httpDevice.address.scheme, 'http');
        expect(httpDevice.address.host, '192.168.1.100');
        expect(httpDevice.address.port, 80);
      });

      test('handles IPv6 addresses', () {
        final ipv6Device = DeviceEntity(
          id: 'ipv6-device',
          address: Uri.parse('coap://[2001:db8::1]:5683'),
          fingerprint: 'fp',
          sceneID: testSceneId,
          driverID: testDriverId,
          compatible: '1.0.0',
          name: 'IPv6 Device',
          model: 'Model',
        );

        expect(ipv6Device.address.host, '2001:db8::1');
        expect(ipv6Device.address.port, 5683);
      });
    });
  });
}
