import 'dart:io';


import 'package:borneo_kernel_abstractions/models/discovered_device.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_app/core/services/devices/mdns.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nsd/nsd.dart' as nsd;

// A minimal fake that behaves like an nsd.Discovery so that we can trigger the
// service listener callbacks without touching the platform plugin.
class _FakeDiscovery extends nsd.Discovery {
  final List<nsd.ServiceListener> _serviceListeners = [];

  _FakeDiscovery() : super('fake');

  @override
  void addServiceListener(nsd.ServiceListener listener) {
    _serviceListeners.add(listener);
  }

  @override
  void removeServiceListener(nsd.ServiceListener listener) {
    _serviceListeners.remove(listener);
  }

  /// Emit an event to all registered listeners.
  void emit(nsd.Service service, nsd.ServiceStatus status) {
    for (final l in List<nsd.ServiceListener>.from(_serviceListeners)) {
      l(service, status);
    }
  }
}

void main() {
  group('NsdMdnsDiscovery', () {
    late EventBus bus;
    late _FakeDiscovery fake;
    late NsdMdnsDiscovery subject;
    late List<DiscoveredDevice> found;

    setUp(() {
      bus = EventBus();
      fake = _FakeDiscovery();
      subject = NsdMdnsDiscovery(fake, '_test._tcp', bus);
      found = [];
      bus.on<FoundDeviceEvent>().listen((e) => found.add(e.discovered));
    });

    tearDown(() async {
      // try to stop; we don't care if it fails since this is a fake
      try {
        await subject.stop();
      } catch (_) {}
      // dispose may assert if stop wasn't called; ignore failures
      try {
        subject.dispose();
      } catch (_) {}
    });

    test('prefers numeric address when available', () async {
      final service = nsd.Service(
        name: 'foo',
        type: '_test._tcp',
        host: 'foo.local',
        port: 1234,
        addresses: [InternetAddress('192.168.0.5')],
        txt: {},
      );

      fake.emit(service, nsd.ServiceStatus.found);
      // event bus dispatch may be asynchronous
      await Future<void>.delayed(Duration.zero);

      expect(found, hasLength(1));
      expect(found.first.host, '192.168.0.5');
      expect(found.first.port, 1234);
    });

    test('falls back to service.host when no addresses', () async {
      final service = nsd.Service(name: 'bar', type: '_test._tcp', host: 'bar.local', port: 4321, txt: {});

      fake.emit(service, nsd.ServiceStatus.found);
      await Future<void>.delayed(Duration.zero);

      expect(found, hasLength(1));
      expect(found.first.host, 'bar.local');
      expect(found.first.port, 4321);
    });
  });
}
