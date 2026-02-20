import 'dart:async';

// imports of interfaces pulled indirectly via mocks
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';
import 'package:test/test.dart';

import 'mocks.dart';

void main() {
  group('Interface mocks', () {
    test('DiscoveryManager mock emits devices', () async {
      final mgr = MockDiscoveryManager();
      expect(mgr.isActive, isFalse);
      mgr.start();
      expect(mgr.isActive, isTrue);

      final events = <DiscoveredDevice>[];
      final sub = mgr.onDeviceFound.listen(events.add);

      // use the concrete helper defined in mocks
      final dev = TestMdnsDiscoveredDevice(host: 'a', port: 80);
      mgr.addDevice(dev);
      await Future.delayed(Duration.zero);
      expect(events, contains(dev));
      sub.cancel();
    });

    test('BindingEngine busy flag and probe results', () async {
      final eng = MockBindingEngine();
      expect(eng.isBusy, isFalse);
      final device = TestDevice('x', 'http://x');
      eng.setProbeResult('x', false);
      final result = await eng.tryBind(device, 'foo');
      expect(result, isFalse);
    });

    test('HeartbeatService start/suspend/resume', () async {
      final svc = MockHeartbeatService();
      expect(svc.isActive, isFalse);
      await svc.start();
      expect(svc.isActive, isTrue);
      svc.suspend();
      expect(svc.isActive, isFalse);
      svc.resume();
      expect(svc.isActive, isTrue);
    });

    test('DriverFactory returns provided driver', () {
      final fact = MockDriverFactory();
      final drv = MockDriver('d');
      fact.add('d', drv);
      expect(fact.create('d'), equals(drv));
    });

    test('EventDispatcher forwards and filters types', () async {
      final disp = MockEventDispatcher();
      final list = <int>[];
      disp.on<int>().listen(list.add);
      disp.fire(1);
      disp.fire('no');
      await Future.delayed(Duration.zero);
      expect(list, [1]);
    });

    test('DeviceBus stub provides streams', () async {
      final bus = MockDeviceBus();
      expect(bus.id, 'mock');
      final f = bus.onDeviceFound.listen((_) {});
      final l = bus.onDeviceLost.listen((_) {});
      await bus.start();
      await bus.connect('any');
      await bus.disconnect('any');
      await bus.stop();
      await f.cancel();
      await l.cancel();
    });
  });
}
