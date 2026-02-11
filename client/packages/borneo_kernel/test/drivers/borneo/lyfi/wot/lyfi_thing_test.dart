import 'package:test/test.dart';

import 'package:borneo_kernel/drivers/borneo/lyfi/wot/wot_thing.dart';

import '../../../../mocks.dart';

void main() {
  group('LyfiThing', () {
    late MockDevice mockDevice;
    late MockDeviceEventBus mockDeviceEventBus;
    late MockBorneoDeviceApi mockBorneoApi;
    late MockLyfiDeviceApi mockLyfiApi;
    late MockLogger mockLogger;

    setUp(() {
      mockDevice = MockDevice('test-device', 'http://192.168.1.100');
      mockDeviceEventBus = MockDeviceEventBus();
      mockBorneoApi = MockBorneoDeviceApi();
      mockLyfiApi = MockLyfiDeviceApi();
      mockLogger = MockLogger();
    });

    group('Constructor', () {
      test('should create LyfiThing with required parameters', () {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Test Lyfi',
          logger: mockLogger,
        );

        expect(lyfiThing.id, equals('test-device'));
        expect(lyfiThing.title, equals('Test Lyfi'));
        expect(lyfiThing.type, contains('OnOffSwitch'));
        expect(lyfiThing.type, contains('Light'));
        expect(lyfiThing.isOffline, isFalse);
      });

      test('should create offline LyfiThing using factory constructor', () {
        final lyfiThing = LyfiThing.offline(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          title: 'Offline Lyfi',
          logger: mockLogger,
        );

        expect(lyfiThing.id, equals('test-device'));
        expect(lyfiThing.title, equals('Offline Lyfi'));
        expect(lyfiThing.isOffline, isTrue);
        expect(lyfiThing.borneoApi, isNull);
        expect(lyfiThing.lyfiApi, isNull);
      });
    });

    group('Guard Methods', () {
      test('canWriteProperty should return true by default', () {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Test Lyfi',
        );

        expect(lyfiThing.canWriteProperty('on'), isTrue);
      });

      test('canWriteProperty should use canWrite function when provided', () {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Test Lyfi',
          canWrite: () => false,
        );

        expect(lyfiThing.canWriteProperty('on'), isFalse);
      });

      test('getWriteGuardError should return appropriate error message', () {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Test Lyfi',
        );

        expect(lyfiThing.getWriteGuardError('on'), equals('Device is offline or unbound.'));
      });

      test('canPerformAction should return true by default', () {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Test Lyfi',
        );

        expect(lyfiThing.canPerformAction('test-action'), isTrue);
      });

      test('canPerformAction should use canWrite function when provided', () {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Test Lyfi',
          canWrite: () => false,
        );

        expect(lyfiThing.canPerformAction('test-action'), isFalse);
      });

      test('getActionGuardError should return appropriate error message', () {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Test Lyfi',
        );

        expect(lyfiThing.getActionGuardError('test-action'), equals('Device is offline or unbound.'));
      });
    });

    group('bindToOnlineApis', () {
      test('should bind APIs and set offline to false', () async {
        final lyfiThing = LyfiThing.offline(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          title: 'Offline Lyfi',
        );

        expect(lyfiThing.isOffline, isTrue);

        await lyfiThing.bindToOnlineApis(mockBorneoApi, mockLyfiApi);

        expect(lyfiThing.isOffline, isFalse);
        expect(lyfiThing.borneoApi, equals(mockBorneoApi));
        expect(lyfiThing.lyfiApi, equals(mockLyfiApi));
      });

      test('should not bind if already online', () async {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Online Lyfi',
        );

        final newBorneoApi = MockBorneoDeviceApi();
        final newLyfiApi = MockLyfiDeviceApi();

        await lyfiThing.bindToOnlineApis(newBorneoApi, newLyfiApi);

        // Should not change since already online
        expect(lyfiThing.borneoApi, equals(mockBorneoApi));
        expect(lyfiThing.lyfiApi, equals(mockLyfiApi));
      });
    });

    group('initialize', () {
      test('should initialize online device', () async {
        final lyfiThing = LyfiThing(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          borneoApi: mockBorneoApi,
          lyfiApi: mockLyfiApi,
          title: 'Test Lyfi',
          logger: mockLogger,
        );

        await lyfiThing.initialize();

        // Verify properties are created
        expect(lyfiThing.hasProperty('on'), isTrue);
        expect(lyfiThing.hasProperty('state'), isTrue);
        expect(lyfiThing.hasProperty('mode'), isTrue);
        expect(lyfiThing.hasProperty('color'), isTrue);
        expect(lyfiThing.hasProperty('schedule'), isTrue);
      });

      test('should initialize offline device without binding', () async {
        final lyfiThing = LyfiThing.offline(
          device: mockDevice,
          deviceEvents: mockDeviceEventBus,
          title: 'Offline Lyfi',
          logger: mockLogger,
        );

        await lyfiThing.initialize();

        // Properties should still be created with defaults
        expect(lyfiThing.hasProperty('on'), isTrue);
      });
    });
  });
}
