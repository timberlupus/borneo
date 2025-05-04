import 'dart:async';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:event_bus/event_bus.dart';
import 'package:nsd/nsd.dart' as nsd;

import 'package:borneo_kernel_abstractions/mdns.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';

class NsdMdnsDiscovery implements IMdnsDiscovery {
  bool _isDisposed = false;
  bool _isStopped = false;
  final String _serviceType;
  final nsd.Discovery _discovery;
  final EventBus _eventBus;

  NsdMdnsDiscovery(this._discovery, this._serviceType, this._eventBus) {
    _discovery.addServiceListener(_onServiceDiscovered);
  }

  @override
  Future<void> stop() async {
    assert(!_isStopped);
    if (_isDisposed) {
      throw ObjectDisposedException(message:'The object has been disposed!');
    }
    await nsd.stopDiscovery(_discovery);
    _isStopped = true;
  }

  void _onServiceDiscovered(nsd.Service service, nsd.ServiceStatus status) {
    if (status == nsd.ServiceStatus.found) {
      final discovered = MdnsDiscoveredDevice(
        host: service.host ?? 'ERROR!!!',
        port: service.port,
        serviceType: service.type,
        name: service.name,
        txt: service.txt,
      );
      _eventBus.fire(FoundDeviceEvent(discovered));
    }
  }

  @override
  String get serviceType => _serviceType;

  @override
  void dispose() {
    if (!_isStopped) {
      stop();
    }
    if (!_isDisposed) {
      _discovery.removeServiceListener(_onServiceDiscovered);
      _isDisposed = true;
    }
  }
}

class NsdMdnsProvider implements IMdnsProvider {
  @override
  Future<IMdnsDiscovery> startDiscovery(String serviceType, EventBus eventBus) async {
    final nsdDiscovery = await nsd.startDiscovery(serviceType, autoResolve: true, ipLookupType: nsd.IpLookupType.any);
    final discovery = NsdMdnsDiscovery(nsdDiscovery, serviceType, eventBus);
    return discovery;
  }
}
