import 'dart:async';

import 'package:borneo_kernel/kernel.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('DefaultKernel', () {
    late MockLogger mockLogger;
    late MockDriverRegistry mockDriverRegistry;
    late MockMdnsProvider mockMdnsProvider;
    late DefaultKernel kernel;
    late MockDriver testDriver;

    setUp(() {
      mockLogger = MockLogger();
      mockDriverRegistry = MockDriverRegistry();
      mockMdnsProvider = MockMdnsProvider();
      testDriver = MockDriver('test-driver');

      // 设置测试驱动程序
      final driverDescriptor = createTestDriverDescriptor('test-driver', testDriver);
      mockDriverRegistry.addDriver('test-driver', driverDescriptor);

      kernel = DefaultKernel(mockLogger, mockDriverRegistry, mdnsProvider: mockMdnsProvider);
    });

    tearDown(() {
      kernel.dispose();
    });

    group('Initialization', () {
      test('should not be initialized initially', () {
        expect(kernel.isInitialized, isFalse);
      });

      test('should be initialized after calling start', () async {
        await kernel.start();
        expect(kernel.isInitialized, isTrue);
      });

      test('should throw exception when accessing methods before initialization', () {
        expect(() => kernel.getBoundDevice('test'), throwsA(isA<Exception>()));
      });
    });

    group('Device Registration', () {
      test('should register and unregister devices', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');

        kernel.registerDevice(deviceDescriptor);
        expect(kernel.isBound('device1'), isFalse);

        kernel.unregisterDevice('device1');
      });

      test('should register multiple devices', () async {
        await kernel.start();

        final device1 = TestDevice('device1', 'http://192.168.1.100');
        final device2 = TestDevice('device2', 'http://192.168.1.101');
        final devices = [
          BoundDeviceDescriptor(device: device1, driverID: 'test-driver'),
          BoundDeviceDescriptor(device: device2, driverID: 'test-driver'),
        ];

        kernel.registerDevices(devices);

        kernel.unregisterAllDevices();
      });
    });

    group('Device Binding', () {
      test('should bind and unbind device successfully', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);

        // 绑定设备
        await kernel.bind(device, 'test-driver');
        expect(kernel.isBound('device1'), isTrue);
        expect(testDriver.probedDevices, contains('device1'));

        final boundDevice = kernel.getBoundDevice('device1');
        expect(boundDevice.device.id, equals('device1'));
        expect(boundDevice.driverID, equals('test-driver'));

        // 解绑设备
        await kernel.unbind('device1');
        expect(kernel.isBound('device1'), isFalse);
        expect(testDriver.removedDevices, contains('device1'));
      });

      test('should handle probe failure during binding', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);

        // 设置探测失败
        testDriver.setProbeResult('device1', false);

        expect(() => kernel.bind(device, 'test-driver'), throwsA(isA<Exception>()));
      });

      test('should try bind and return false on failure', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);

        // 设置探测失败
        testDriver.setProbeResult('device1', false);

        final result = await kernel.tryBind(device, 'test-driver');
        expect(result, isFalse);
      });

      test('should try bind and return true on success', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);

        final result = await kernel.tryBind(device, 'test-driver');
        expect(result, isTrue);
        expect(kernel.isBound('device1'), isTrue);
      });

      test('should unbind all devices', () async {
        await kernel.start();

        final device1 = TestDevice('device1', 'http://192.168.1.100');
        final device2 = TestDevice('device2', 'http://192.168.1.101');
        final devices = [device1, device2];

        for (final device in devices) {
          final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
          kernel.registerDevice(deviceDescriptor);
          await kernel.bind(device, 'test-driver');
        }

        expect(kernel.boundDevices.length, equals(2));

        await kernel.unbindAll();
        expect(kernel.boundDevices.length, equals(0));
      });

      test('heartbeat suspend/resume does not throw', () async {
        await kernel.start();
        kernel.suspendHeartbeat();
        kernel.resumeHeartbeat();
        // binding while heartbeat suspended should still work
        final device = TestDevice('d1', 'http://1');
        kernel.registerDevice(BoundDeviceDescriptor(device: device, driverID: 'test-driver'));
        await kernel.bind(device, 'test-driver');
      });

      test('concurrent binds complete without error', () async {
        await kernel.start();
        final deviceA = TestDevice('A', 'http://a');
        final deviceB = TestDevice('B', 'http://b');
        kernel.registerDevice(BoundDeviceDescriptor(device: deviceA, driverID: 'test-driver'));
        kernel.registerDevice(BoundDeviceDescriptor(device: deviceB, driverID: 'test-driver'));

        final f1 = kernel.bind(deviceA, 'test-driver');
        final f2 = kernel.bind(deviceB, 'test-driver');
        await Future.wait([f1, f2]);
      });
    });

    group('Event Handling', () {
      test('should emit device bound event when device is bound', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);

        DeviceBoundEvent? receivedEvent;
        kernel.events.on<DeviceBoundEvent>().listen((event) {
          receivedEvent = event;
        });

        await kernel.bind(device, 'test-driver');

        // 等待事件传播
        await Future.delayed(Duration(milliseconds: 10));

        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.device.id, equals('device1'));
      });

      test('should emit device removed event when device is unbound', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);
        await kernel.bind(device, 'test-driver');

        DeviceRemovedEvent? receivedEvent;
        kernel.events.on<DeviceRemovedEvent>().listen((event) {
          receivedEvent = event;
        });

        await kernel.unbind('device1');

        // 等待事件传播
        await Future.delayed(Duration(milliseconds: 10));

        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.device.id, equals('device1'));
      });

      test('should handle device offline event by unbinding device', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);
        await kernel.bind(device, 'test-driver');

        expect(kernel.isBound('device1'), isTrue);

        // 模拟设备离线事件
        kernel.events.fire(DeviceOfflineEvent(device));

        // 等待事件处理
        await Future.delayed(Duration(milliseconds: 50));

        expect(kernel.isBound('device1'), isFalse);
      });
    });

    group('Device Discovery', () {
      test('supports custom DiscoveryManager injection', () async {
        await kernel.start();
        final mgr = MockDiscoveryManager();
        // build new kernel with supplied manager and the same mocks
        final k2 = DefaultKernel(mockLogger, mockDriverRegistry, mdnsProvider: mockMdnsProvider, discoveryManager: mgr);
        await k2.start();
        expect(k2.isScanning, isFalse);
        await k2.startDevicesScanning();
        expect(mgr.isActive, isTrue);
        await k2.stopDevicesScanning();
        expect(mgr.isActive, isFalse);
      });

      test('supports custom BindingEngine injection', () async {
        await kernel.start();
        final eng = MockBindingEngine();
        final k2 = DefaultKernel(mockLogger, mockDriverRegistry, mdnsProvider: mockMdnsProvider, bindingEngine: eng);
        await k2.start();
        final device = TestDevice('d1', 'http://d1');
        k2.registerDevice(BoundDeviceDescriptor(device: device, driverID: 'test-driver'));
        await k2.bind(device, 'test-driver');
        expect(eng.bindCalled, isTrue);
      });

      test('kernel forwards unbound device lost events', () async {
        await kernel.start();
        final mgr = MockDiscoveryManager();
        final k2 = DefaultKernel(mockLogger, mockDriverRegistry, mdnsProvider: mockMdnsProvider, discoveryManager: mgr);
        await k2.start();
        UnboundDeviceLostEvent? got;
        k2.events.on<UnboundDeviceLostEvent>().listen((e) {
          got = e;
        });
        mgr.emitLost('abc');
        await Future.delayed(Duration.zero);
        expect(got?.deviceId, 'abc');
      });
      test('should start and stop device scanning', () async {
        await kernel.start();

        expect(kernel.isScanning, isFalse);

        await kernel.startDevicesScanning();
        expect(kernel.isScanning, isTrue);
        expect(mockMdnsProvider.startedServices, contains('_test._tcp'));

        await kernel.stopDevicesScanning();
        expect(kernel.isScanning, isFalse);

        final discoveries = mockMdnsProvider.discoveries.values;
        expect(discoveries.every((d) => d.isStopped), isTrue);
      });

      test('should handle found device event', () async {
        await kernel.start();

        final discoveredDevice = TestMdnsDiscoveredDevice(host: '192.168.1.100', port: 8080, name: 'Test Device');

        UnboundDeviceDiscoveredEvent? receivedEvent;
        kernel.events.on<UnboundDeviceDiscoveredEvent>().listen((event) {
          receivedEvent = event;
        });

        // 模拟发现设备事件
        kernel.events.fire(FoundDeviceEvent(discoveredDevice));

        // 等待事件传播
        await Future.delayed(Duration(milliseconds: 10));

        expect(receivedEvent, isNotNull);
        expect(receivedEvent!.matched.address.host, equals('192.168.1.100'));
      });

      test('should start scanning with timeout', () async {
        await kernel.start();

        final timeoutCompleter = Completer<void>();
        kernel.events.on<DeviceDiscoveringStoppedEvent>().listen((_) {
          timeoutCompleter.complete();
        });

        await kernel.startDevicesScanning(timeout: Duration(milliseconds: 100));

        // 等待超时停止
        await timeoutCompleter.future.timeout(Duration(seconds: 1));

        expect(kernel.isScanning, isFalse);
      });
    });

    group('Driver Management', () {
      test('should activate driver when needed', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);

        await kernel.bind(device, 'test-driver');

        expect(kernel.activatedDrivers, contains(testDriver));
      });

      test('should purge unused drivers', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);

        await kernel.bind(device, 'test-driver');
        expect(kernel.activatedDrivers.length, equals(1));
        expect(testDriver.isDisposed, isFalse);

        await kernel.unbind('device1');

        // 驱动程序应该被清理
        expect(testDriver.isDisposed, isTrue);
      });
    });

    group('Cancellation', () {
      test('should respect cancellation token during binding', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);

        final cancelToken = CancellationToken();

        // 预先取消令牌
        cancelToken.cancel();

        expect(() => kernel.bind(device, 'test-driver', cancelToken: cancelToken), throwsA(isA<CancelledException>()));
      });

      test('should respect cancellation token during scanning', () async {
        await kernel.start();

        final cancelToken = CancellationToken();

        // 启动扫描并立即取消
        final scanFuture = kernel.startDevicesScanning(cancelToken: cancelToken);
        Timer.run(() => cancelToken.cancel());

        await scanFuture;
        // 扫描应该能够处理取消而不抛出异常
      });
    });

    group('Disposal', () {
      test('should dispose all resources', () async {
        await kernel.start();

        final device = TestDevice('device1', 'http://192.168.1.100');
        final deviceDescriptor = BoundDeviceDescriptor(device: device, driverID: 'test-driver');
        kernel.registerDevice(deviceDescriptor);
        await kernel.bind(device, 'test-driver');

        kernel.dispose();

        expect(testDriver.isDisposed, isTrue);
      });

      test('should handle multiple dispose calls safely', () async {
        await kernel.start();

        kernel.dispose();

        // 多次调用 dispose 不应该抛出异常
        expect(() => kernel.dispose(), returnsNormally);
      });
    });
  });
}
