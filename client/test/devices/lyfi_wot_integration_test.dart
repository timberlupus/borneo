import 'package:test/test.dart';
import 'package:mockito/mockito.dart';
import 'package:borneo_app/devices/borneo/lyfi/manifest.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/core/services/device_manager.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/models/driver_data.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_wot/wot.dart';

// Mocks
class MockDeviceManager extends Mock implements DeviceManager {}

class MockBoundDevice extends Mock implements BoundDevice {}

class MockDevice extends Mock implements Device {}

class MockDriverData extends Mock implements DriverData {}

class MockBorneoApi extends Mock implements IBorneoDeviceApi {}

class MockLyfiApi extends Mock implements ILyfiDeviceApi {}

void main() {
  group('LyfiThing Integration Tests', () {
    late DeviceEntity testDevice;
    late MockDeviceManager mockDeviceManager;
    late MockBoundDevice mockBoundDevice;
    late MockDevice mockDevice;
    late MockDriverData mockDriverData;
    late MockBorneoApi mockBorneoApi;
    late MockLyfiApi mockLyfiApi;
    late DeviceEventBus deviceEventBus;

    setUp(() {
      testDevice = DeviceEntity(
        id: 'test-lyfi-device',
        name: 'Test LyFi Device',
        driverID: 'borneo-lyfi',
        sceneID: 'test-scene',
        lastSeen: DateTime.now(),
        fingerprint: 'test-fingerprint',
        address: 'coap://192.168.1.100:5683',
      );

      mockDeviceManager = MockDeviceManager();
      mockBoundDevice = MockBoundDevice();
      mockDevice = MockDevice();
      mockDriverData = MockDriverData();
      mockBorneoApi = MockBorneoApi();
      mockLyfiApi = MockLyfiApi();
      deviceEventBus = DeviceEventBus();
    });

    test('should create basic WotThing when device is not bound', () {
      // Arrange
      when(mockDeviceManager.isBound(testDevice.id)).thenReturn(false);

      // Act
      final metadata = LyfiDeviceModuleMetadata();
      final wotThing = metadata.createWotThing(testDevice, mockDeviceManager);

      // Assert
      expect(wotThing, isNotNull);
      expect(wotThing.id, equals(testDevice.id));
      expect(wotThing.title, equals(testDevice.name));
      expect(wotThing.type, contains('Light'));

      // Check that basic properties are created
      expect(wotThing.getProperty('on'), isNotNull);
      expect(wotThing.getProperty('state'), isNotNull);
      expect(wotThing.getProperty('mode'), isNotNull);
      expect(wotThing.getProperty('color'), isNotNull);
    });

    test('should create LyfiThing when device is bound', () {
      // Arrange
      when(mockDeviceManager.isBound(testDevice.id)).thenReturn(true);
      when(mockDeviceManager.getBoundDevice(testDevice.id)).thenReturn(mockBoundDevice);
      when(mockBoundDevice.api<IBorneoDeviceApi>()).thenReturn(mockBorneoApi);
      when(mockBoundDevice.api<ILyfiDeviceApi>()).thenReturn(mockLyfiApi);
      when(mockBoundDevice.device).thenReturn(mockDevice);
      when(mockDevice.driverData).thenReturn(mockDriverData);
      when(mockDriverData.deviceEvents).thenReturn(deviceEventBus);
      when(mockDevice.id).thenReturn(testDevice.id);

      // Act
      final metadata = LyfiDeviceModuleMetadata();
      final wotThing = metadata.createWotThing(testDevice, mockDeviceManager);

      // Assert
      expect(wotThing, isNotNull);
      expect(wotThing.id, equals(testDevice.id));
      expect(wotThing.title, equals(testDevice.name));

      // Verify that APIs were accessed
      verify(mockBoundDevice.api<IBorneoDeviceApi>()).called(1);
      verify(mockBoundDevice.api<ILyfiDeviceApi>()).called(1);
    });

    test('should fall back to basic WotThing when API access fails', () {
      // Arrange
      when(mockDeviceManager.isBound(testDevice.id)).thenReturn(true);
      when(mockDeviceManager.getBoundDevice(testDevice.id)).thenThrow(Exception('API access failed'));

      // Act
      final metadata = LyfiDeviceModuleMetadata();
      final wotThing = metadata.createWotThing(testDevice, mockDeviceManager);

      // Assert
      expect(wotThing, isNotNull);
      expect(wotThing.id, equals(testDevice.id));
      expect(wotThing.title, equals(testDevice.name));

      // Should still have basic properties
      expect(wotThing.getProperty('on'), isNotNull);
      expect(wotThing.getProperty('state'), isNotNull);
      expect(wotThing.getProperty('mode'), isNotNull);
      expect(wotThing.getProperty('color'), isNotNull);
    });
  });
}
