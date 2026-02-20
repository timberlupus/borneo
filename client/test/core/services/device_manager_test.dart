import 'dart:collection';

import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/devices/device_manager_impl.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/device_module_metadata.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast_memory.dart';

void main() {
  group('DeviceManagerImpl Tests', () {
    late DeviceManagerImpl deviceManager;
    late Database testDb;
    late TestKernel testKernel;
    late TestEventBus testGlobalBus;
    late TestSceneManager testSceneManager;
    late TestGroupManager testGroupManager;
    late TestDeviceModuleRegistry testDeviceModuleRegistry;
    late TestLogger testLogger;

    // Test data
    late DeviceEntity testDevice;

    setUp(() async {
      // Create in-memory database for testing
      testDb = await databaseFactoryMemory.openDatabase('test.db');

      // Create test doubles
      testKernel = TestKernel();
      testGlobalBus = TestEventBus();
      testSceneManager = TestSceneManager();
      testGroupManager = TestGroupManager();
      testDeviceModuleRegistry = TestDeviceModuleRegistry();
      testLogger = TestLogger();

      // Setup test scene
      final testSceneEntity = SceneEntity(
        id: 'test-scene-id',
        name: 'Test Scene',
        isCurrent: true,
        lastAccessTime: DateTime.now(),
      );
      testSceneManager.currentScene = testSceneEntity;

      // Setup test device
      testDevice = DeviceEntity(
        id: 'test-device-id',
        name: 'Test Device',
        sceneID: 'test-scene-id',
        driverID: 'test-driver',
        fingerprint: 'test-fingerprint',
        address: Uri.parse('coap://192.168.1.100:5683'),
        compatible: 'test-compatible',
        model: 'test-model',
      );

      // Create device manager instance
      deviceManager = DeviceManagerImpl(
        testDb,
        testKernel,
        testGlobalBus,
        testSceneManager,
        testGroupManager,
        testDeviceModuleRegistry,
        logger: testLogger,
      );
    });

    tearDown(() async {
      deviceManager.dispose();
      await testDb.close();
    });

    group('Initialization', () {
      test('should initialize successfully', () async {
        // Act
        await deviceManager.initialize();

        // Assert
        expect(deviceManager.isInitialized, isTrue);
        expect(testKernel.startCalled, isTrue);
      });

      test('should throw assertion error if already initialized', () async {
        // Arrange
        await deviceManager.initialize();

        // Act & Assert
        expect(() => deviceManager.initialize(), throwsA(isA<AssertionError>()));
      });
    });

    group('Device Database Operations', () {
      setUp(() async {
        await deviceManager.initialize();
      });

      test('should add device to database', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');

        // Act
        await store.record(testDevice.id).put(testDb, testDevice.toMap());
        final result = await deviceManager.getDevice(testDevice.id);

        // Assert
        expect(result.id, equals(testDevice.id));
        expect(result.name, equals(testDevice.name));
        expect(result.sceneID, equals(testDevice.sceneID));
        expect(result.isDemo, isFalse);
      });

      test('should update device name', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        // Act
        await deviceManager.update(testDevice.id, name: 'Updated Name');

        // Assert
        final updatedDevice = await deviceManager.getDevice(testDevice.id);
        expect(updatedDevice.name, equals('Updated Name'));
      });

      test('should delete device from database', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        // Act
        await deviceManager.delete(testDevice.id);

        // Assert
        final record = await store.record(testDevice.id).get(testDb);
        expect(record, isNull);
      });

      test('should fetch devices in current scene only', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        final otherSceneDevice = DeviceEntity(
          id: 'other-device',
          name: 'Other Device',
          sceneID: 'other-scene',
          driverID: 'test-driver',
          fingerprint: 'other-fingerprint',
          address: Uri.parse('coap://192.168.1.102:5683'),
          compatible: 'test-compatible',
          model: 'test-model',
        );
        await store.record(otherSceneDevice.id).put(testDb, otherSceneDevice.toMap());

        // Act
        final result = await deviceManager.fetchAllDevicesInScene();

        // Assert
        expect(result.length, equals(1));
        expect(result.first.id, equals(testDevice.id));
        expect(result.first.sceneID, equals('test-scene-id'));
      });

      test('should check if device is new', () async {
        // Arrange
        final descriptor = TestSupportedDeviceDescriptor('unique-fingerprint');

        // Act
        final result = await deviceManager.isNewDevice(descriptor);

        // Assert
        expect(result, isTrue);
      });

      test('should find device by fingerprint', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        // Act
        final result = await deviceManager.singleOrDefaultByFingerprint(testDevice.fingerprint);

        // Assert
        expect(result, isNotNull);
        expect(result!.id, equals(testDevice.id));
        expect(result.fingerprint, equals(testDevice.fingerprint));
      });
    });

    group('Device Binding Operations', () {
      setUp(() async {
        await deviceManager.initialize();
      });

      test('should bind device', () async {
        // Act
        await deviceManager.bind(testDevice);

        // Assert
        expect(testKernel.bindCalled, isTrue);
        expect(testKernel.lastBoundDeviceId, equals(testDevice.id));
      });

      test('should try bind device', () async {
        // Arrange
        testKernel.tryBindResult = true;

        // Act
        final result = await deviceManager.tryBind(testDevice);

        // Assert
        expect(result, isTrue);
        expect(testKernel.tryBindCalled, isTrue);
      });

      test('should unbind device', () async {
        // Act
        await deviceManager.unbind(testDevice.id);

        // Assert
        expect(testKernel.unbindCalled, isTrue);
        expect(testKernel.lastUnboundDeviceId, equals(testDevice.id));
      });

      test('should check if device is bound', () {
        // Arrange
        testKernel.boundDeviceIds.add(testDevice.id);

        // Act
        final result = deviceManager.isBound(testDevice.id);

        // Assert
        expect(result, isTrue);
      });
    });

    group('Device Discovery', () {
      setUp(() async {
        await deviceManager.initialize();
      });

      test('should start discovery', () async {
        // Act
        await deviceManager.startDiscovery(timeout: const Duration(seconds: 30));

        // Assert
        expect(testKernel.startScanningCalled, isTrue);
        expect(deviceManager.isDiscoverying, isTrue);
      });

      test('should stop discovery', () async {
        // Arrange
        await deviceManager.startDiscovery();

        // Act
        await deviceManager.stopDiscovery();

        // Assert
        expect(testKernel.stopScanningCalled, isTrue);
        expect(deviceManager.isDiscoverying, isFalse);
      });
    });

    group('Error Handling', () {
      setUp(() async {
        await deviceManager.initialize();
      });

      test('should throw KeyNotFoundException when updating non-existent device', () async {
        // Act & Assert
        expect(() => deviceManager.update('non-existent-id', name: 'New Name'), throwsA(isA<KeyNotFoundException>()));
      });

      test('should throw KeyNotFoundException when moving to non-existent group', () async {
        // Arrange
        final store = stringMapStoreFactory.store('devices');
        await store.record(testDevice.id).put(testDb, testDevice.toMap());

        // Act & Assert
        expect(
          () => deviceManager.moveToGroup(testDevice.id, 'non-existent-group'),
          throwsA(isA<KeyNotFoundException>()),
        );
      });
    });

    group('Disposal', () {
      test('should dispose resources properly', () {
        // Act & Assert - should not throw any exceptions
        deviceManager.dispose();

        // Verify that dispose can be called multiple times safely
        deviceManager.dispose();
      });
    });

    group('Heartbeat suspension', () {
      test('reloadAllDevices suspends and resumes heartbeat', () async {
        // Arrange: kernel starts in default state
        expect(testKernel.heartbeatSuspended, isFalse);
        expect(testKernel.heartbeatResumed, isFalse);

        // Act
        await deviceManager.reloadAllDevices();

        // Assert
        expect(testKernel.heartbeatSuspended, isTrue, reason: 'heartbeat should be suspended before heavy operations');
        expect(testKernel.heartbeatResumed, isTrue, reason: 'heartbeat should be resumed after operations complete');
      });
    });
  });
}

// Simple test doubles without complex inheritance issues
class TestKernel implements IKernel {
  bool _isScanning = false;
  bool _isInitialized = false;
  final List<String> boundDeviceIds = [];
  final List<BoundDevice> _boundDevices = [];
  final TestGlobalDevicesEventBus _events = TestGlobalDevicesEventBus();

  // tracks whether suspend/resume were invoked
  bool heartbeatSuspended = false;
  bool heartbeatResumed = false;

  // Test tracking
  bool startCalled = false;
  bool bindCalled = false;
  bool tryBindCalled = false;
  bool unbindCalled = false;
  bool startScanningCalled = false;
  bool stopScanningCalled = false;

  String? lastBoundDeviceId;
  String? lastUnboundDeviceId;
  bool tryBindResult = true;

  @override
  bool get isScanning => _isScanning;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Iterable<Driver> get activatedDrivers => [];

  @override
  Iterable<BoundDevice> get boundDevices => _boundDevices;

  @override
  GlobalDevicesEventBus get events => _events;

  @override
  Future<void> start() async {
    startCalled = true;
    _isInitialized = true;
  }

  @override
  void suspendHeartbeat() {
    heartbeatSuspended = true;
  }

  @override
  void resumeHeartbeat() {
    heartbeatResumed = true;
  }

  @override
  bool isBound(String deviceID) => boundDeviceIds.contains(deviceID);

  @override
  BoundDevice getBoundDevice(String deviceID) {
    // Create a mock BoundDevice for testing
    final device = TestDevice(deviceID);
    final driver = TestDriver();
    return BoundDevice('test-driver', device, driver);
  }

  @override
  Future<bool> tryBind(dynamic device, String driverID, {CancellationToken? cancelToken}) async {
    tryBindCalled = true;
    lastBoundDeviceId = device.id;
    if (tryBindResult) {
      boundDeviceIds.add(device.id);
      final testDevice = TestDevice(device.id);
      final testDriver = TestDriver();
      _boundDevices.add(BoundDevice(driverID, testDevice, testDriver));
    }
    return tryBindResult;
  }

  @override
  Future<void> bind(dynamic device, String driverID, {CancellationToken? cancelToken}) async {
    bindCalled = true;
    lastBoundDeviceId = device.id;
    boundDeviceIds.add(device.id);
    final testDevice = TestDevice(device.id);
    final testDriver = TestDriver();
    _boundDevices.add(BoundDevice(driverID, testDevice, testDriver));
  }

  @override
  Future<void> unbind(String deviceID, {CancellationToken? cancelToken}) async {
    unbindCalled = true;
    lastUnboundDeviceId = deviceID;
    boundDeviceIds.remove(deviceID);
    _boundDevices.removeWhere((d) => d.device.id == deviceID);
  }

  @override
  Future<void> unbindAll({CancellationToken? cancelToken}) async {
    boundDeviceIds.clear();
    _boundDevices.clear();
  }

  @override
  void registerDevice(dynamic descriptor) {}

  @override
  void registerDevices(Iterable<dynamic> descriptors) {}

  @override
  void unregisterDevice(String deviceID) {}

  @override
  void unregisterAllDevices() {}

  @override
  Future<void> startDevicesScanning({Duration? timeout, CancellationToken? cancelToken}) async {
    startScanningCalled = true;
    _isScanning = true;
  }

  @override
  Future<void> stopDevicesScanning() async {
    stopScanningCalled = true;
    _isScanning = false;
  }

  @override
  void dispose() {}

  @override
  bool get isBusy => false;
}

class TestBoundDevice {
  final Device device;

  TestBoundDevice(this.device);
}

class TestDevice extends Device {
  late DriverData _driverData;

  TestDevice(String id) : super(id: id, fingerprint: 'test-fingerprint', address: Uri.parse('coap://localhost:5683')) {
    _driverData = TestDriverData(this);
  }

  @override
  DriverData get driverData => _driverData;

  @override
  Future<void> setDriverData(DriverData data, {CancellationToken? cancelToken}) async {
    _driverData = data;
  }
}

class TestDriverData extends DriverData {
  TestDriverData(super.device);

  @override
  void dispose() {}
}

class TestDriver extends Driver {
  @override
  Future<bool> probe(Device dev, {CancellationToken? cancelToken}) async => true;

  @override
  Future<bool> remove(Device dev, {CancellationToken? cancelToken}) async => true;

  @override
  Future<bool> heartbeat(Device dev, {CancellationToken? cancelToken}) async => true;

  @override
  void dispose() {}
}

class TestGlobalDevicesEventBus extends EventBus implements GlobalDevicesEventBus {}

class TestEventBus extends EventBus {}

class TestSceneManager implements ISceneManager {
  late SceneEntity currentScene;

  @override
  SceneEntity get current => currentScene;

  Logger? get logger => null;

  // Simplified - only implement what we need for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class TestGroupManager implements IGroupManager {
  // Simplified - only implement what we need for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class TestDeviceModuleRegistry implements IDeviceModuleRegistry {
  @override
  UnmodifiableMapView<String, DeviceModuleMetadata> get metaModules =>
      UnmodifiableMapView(<String, DeviceModuleMetadata>{});
}

class TestLogger implements Logger {
  final List<String> messages = [];

  @override
  void v(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('V: $message');
  }

  @override
  void d(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('D: $message');
  }

  @override
  void i(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('I: $message');
  }

  @override
  void w(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('W: $message');
  }

  @override
  void e(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('E: $message');
  }

  @override
  void wtf(dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('WTF: $message');
  }

  @override
  void log(Level level, dynamic message, {DateTime? time, Object? error, StackTrace? stackTrace}) {
    messages.add('${level.name}: $message');
  }

  @override
  bool isClosed() => false;

  @override
  Future<void> close() async {}

  // Simplified - handle missing methods
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class TestSupportedDeviceDescriptor implements SupportedDeviceDescriptor {
  @override
  final String fingerprint;

  TestSupportedDeviceDescriptor(this.fingerprint);

  // Simplified - handle missing methods
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
