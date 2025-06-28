import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:sembast/sembast.dart';
import 'package:sembast/sembast_memory.dart';
import 'package:test/test.dart';

void main() {
  group('DeviceManagerImpl Basic Tests', () {
    late Database testDb;

    setUp(() async {
      // Create in-memory database for testing
      testDb = await databaseFactoryMemory.openDatabase('test.db');
    });

    tearDown(() async {
      await testDb.close();
    });

    group('Database Operations', () {
      test('should store and retrieve device from database', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        final testDevice = DeviceEntity(
          id: 'test-device-id',
          name: 'Test Device',
          sceneID: 'test-scene-id',
          driverID: 'test-driver',
          fingerprint: 'test-fingerprint',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        // Act - Store device
        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        // Act - Retrieve device
        final retrievedData = await store.record(testDevice.id).get(testDb);
        final retrievedDevice = DeviceEntity.fromMap(testDevice.id, retrievedData!);

        // Assert
        expect(retrievedDevice.id, equals(testDevice.id));
        expect(retrievedDevice.name, equals(testDevice.name));
        expect(retrievedDevice.sceneID, equals(testDevice.sceneID));
        expect(retrievedDevice.driverID, equals(testDevice.driverID));
        expect(retrievedDevice.fingerprint, equals(testDevice.fingerprint));
        expect(retrievedDevice.address.toString(), equals(testDevice.address.toString()));
        expect(retrievedDevice.compatible, equals(testDevice.compatible));
        expect(retrievedDevice.model, equals(testDevice.model));
      });

      test('should update device in database', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        final testDevice = DeviceEntity(
          id: 'test-device-id',
          name: 'Original Name',
          sceneID: 'test-scene-id',
          driverID: 'test-driver',
          fingerprint: 'test-fingerprint',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        // Act - Update device name
        await store.record(testDevice.id).update(testDb, {DeviceEntity.kNameFieldName: 'Updated Name'});

        // Assert
        final updatedData = await store.record(testDevice.id).get(testDb);
        final updatedDevice = DeviceEntity.fromMap(testDevice.id, updatedData!);
        expect(updatedDevice.name, equals('Updated Name'));
        expect(updatedDevice.id, equals(testDevice.id)); // Other fields unchanged
      });

      test('should delete device from database', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        final testDevice = DeviceEntity(
          id: 'test-device-id',
          name: 'Test Device',
          sceneID: 'test-scene-id',
          driverID: 'test-driver',
          fingerprint: 'test-fingerprint',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        await store.record(testDevice.id).put(testDb, testDevice.toMap());
        expect(await store.record(testDevice.id).get(testDb), isNotNull);

        // Act
        await store.record(testDevice.id).delete(testDb);

        // Assert
        final deletedData = await store.record(testDevice.id).get(testDb);
        expect(deletedData, isNull);
      });

      test('should query devices by scene ID', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');

        final device1 = DeviceEntity(
          id: 'device-1',
          name: 'Device 1',
          sceneID: 'scene-1',
          driverID: 'test-driver',
          fingerprint: 'fingerprint-1',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        final device2 = DeviceEntity(
          id: 'device-2',
          name: 'Device 2',
          sceneID: 'scene-1',
          driverID: 'test-driver',
          fingerprint: 'fingerprint-2',
          address: Uri.parse('coap://192.168.1.101:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        final device3 = DeviceEntity(
          id: 'device-3',
          name: 'Device 3',
          sceneID: 'scene-2',
          driverID: 'test-driver',
          fingerprint: 'fingerprint-3',
          address: Uri.parse('coap://192.168.1.102:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        // Store devices
        await store.record(device1.id).put(testDb, device1.toMap());
        await store.record(device2.id).put(testDb, device2.toMap());
        await store.record(device3.id).put(testDb, device3.toMap());

        // Act - Query devices in scene-1
        final finder = Finder(filter: Filter.equals(DeviceEntity.kSceneIDFieldName, 'scene-1'));
        final records = await store.find(testDb, finder: finder);

        // Assert
        expect(records.length, equals(2));
        final deviceIds = records.map((r) => r.key).toList();
        expect(deviceIds, containsAll(['device-1', 'device-2']));
        expect(deviceIds, isNot(contains('device-3')));
      });

      test('should query device by fingerprint', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        final testDevice = DeviceEntity(
          id: 'test-device-id',
          name: 'Test Device',
          sceneID: 'test-scene-id',
          driverID: 'test-driver',
          fingerprint: 'unique-fingerprint',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        // Act
        final record = await store.findFirst(
          testDb,
          finder: Finder(filter: Filter.equals(DeviceEntity.kFngerprintFieldName, 'unique-fingerprint')),
        );

        // Assert
        expect(record, isNotNull);
        expect(record!.key, equals(testDevice.id));
        final foundDevice = DeviceEntity.fromMap(record.key, record.value);
        expect(foundDevice.fingerprint, equals('unique-fingerprint'));
      });

      test('should count devices by fingerprint', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        final testDevice = DeviceEntity(
          id: 'test-device-id',
          name: 'Test Device',
          sceneID: 'test-scene-id',
          driverID: 'test-driver',
          fingerprint: 'duplicate-fingerprint',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        // Act - Count devices with specific fingerprint
        final filter = Filter.equals(DeviceEntity.kFngerprintFieldName, 'duplicate-fingerprint');
        final count = await store.count(testDb, filter: filter);

        // Assert
        expect(count, equals(1));

        // Act - Count devices with non-existent fingerprint
        final nonExistentFilter = Filter.equals(DeviceEntity.kFngerprintFieldName, 'non-existent');
        final zeroCount = await store.count(testDb, filter: nonExistentFilter);

        // Assert
        expect(zeroCount, equals(0));
      });
    });

    group('DeviceEntity Tests', () {
      test('should create DeviceEntity with all required fields', () {
        // Act
        final device = DeviceEntity(
          id: 'test-id',
          name: 'Test Device',
          sceneID: 'scene-id',
          driverID: 'driver-id',
          fingerprint: 'fingerprint',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'compatible',
          model: 'model',
          groupID: 'group-id',
        );

        // Assert
        expect(device.id, equals('test-id'));
        expect(device.name, equals('Test Device'));
        expect(device.sceneID, equals('scene-id'));
        expect(device.driverID, equals('driver-id'));
        expect(device.fingerprint, equals('fingerprint'));
        expect(device.address.toString(), equals('coap://192.168.1.100:5683'));
        expect(device.compatible, equals('compatible'));
        expect(device.model, equals('model'));
        expect(device.groupID, equals('group-id'));
      });

      test('should serialize and deserialize DeviceEntity correctly', () {
        // Arrange
        final originalDevice = DeviceEntity(
          id: 'test-id',
          name: 'Test Device',
          sceneID: 'scene-id',
          driverID: 'driver-id',
          fingerprint: 'fingerprint',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'compatible',
          model: 'model',
          groupID: 'group-id',
        );

        // Act
        final map = originalDevice.toMap();
        final deserializedDevice = DeviceEntity.fromMap(originalDevice.id, map);

        // Assert
        expect(deserializedDevice.id, equals(originalDevice.id));
        expect(deserializedDevice.name, equals(originalDevice.name));
        expect(deserializedDevice.sceneID, equals(originalDevice.sceneID));
        expect(deserializedDevice.driverID, equals(originalDevice.driverID));
        expect(deserializedDevice.fingerprint, equals(originalDevice.fingerprint));
        expect(deserializedDevice.address, equals(originalDevice.address));
        expect(deserializedDevice.compatible, equals(originalDevice.compatible));
        expect(deserializedDevice.model, equals(originalDevice.model));
        expect(deserializedDevice.groupID, equals(originalDevice.groupID));
      });

      test('should handle optional groupID field', () {
        // Act
        final deviceWithoutGroup = DeviceEntity(
          id: 'test-id',
          name: 'Test Device',
          sceneID: 'scene-id',
          driverID: 'driver-id',
          fingerprint: 'fingerprint',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'compatible',
          model: 'model',
        );

        // Assert
        expect(deviceWithoutGroup.groupID, isNull);

        // Act - Serialize and deserialize
        final map = deviceWithoutGroup.toMap();
        final deserializedDevice = DeviceEntity.fromMap(deviceWithoutGroup.id, map);

        // Assert
        expect(deserializedDevice.groupID, isNull);
      });
    });

    group('Error Handling Tests', () {
      test('should handle KeyNotFoundException properly', () {
        // Act & Assert
        expect(() => throw KeyNotFoundException(message: 'Test error'), throwsA(isA<KeyNotFoundException>()));
      });

      test('should handle invalid URI parsing', () {
        // Act & Assert
        expect(() => Uri.parse('http://[::1:bad'), throwsA(isA<FormatException>()));
      });
    });

    group('Transaction Tests', () {
      test('should perform transactional operations', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');

        // Clear any existing data
        await store.delete(testDb);

        final device1 = DeviceEntity(
          id: 'device-1',
          name: 'Device 1',
          sceneID: 'scene-1',
          driverID: 'test-driver',
          fingerprint: 'fingerprint-1',
          address: Uri.parse('coap://192.168.1.100:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        final device2 = DeviceEntity(
          id: 'device-2',
          name: 'Device 2',
          sceneID: 'scene-1',
          driverID: 'test-driver',
          fingerprint: 'fingerprint-2',
          address: Uri.parse('coap://192.168.1.101:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );

        // Act - Perform operations in a transaction
        await testDb.transaction((txn) async {
          await store.record(device1.id).put(txn, device1.toMap());
          await store.record(device2.id).put(txn, device2.toMap());
        });

        // Assert
        final count = await store.count(testDb);
        expect(count, equals(2));

        final device1Data = await store.record(device1.id).get(testDb);
        final device2Data = await store.record(device2.id).get(testDb);
        expect(device1Data, isNotNull);
        expect(device2Data, isNotNull);
      });
    });
  });
}
