import 'dart:async';

import 'package:bonsoir/bonsoir.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';

import 'package:borneo_kernel_abstractions/mdns.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';

final class NsdMdnsDiscovery implements IMdnsDiscovery {
  bool _isDisposed = false;
  bool _isStopped = false;
  final String _serviceType;
  final BonsoirDiscovery _discovery;
  final EventBus _eventBus;
  StreamSubscription<BonsoirDiscoveryEvent>? _eventSub;

  NsdMdnsDiscovery(this._discovery, this._serviceType, this._eventBus) {
    _eventSub = _discovery.eventStream!.listen(_onServiceDiscovered);
    assert(_discovery.isReady);
    _discovery.start();
  }

  @override
  Future<void> stop({CancellationToken? cancelToken}) async {
    assert(!_isStopped);
    if (_isDisposed) {
      throw ObjectDisposedException(message: 'The object has been disposed!');
    }
    _discovery.stop();
    _isStopped = true;
  }

  void _onServiceDiscovered(BonsoirDiscoveryEvent event) {
    if (_isDisposed) {
      return;
    }
    switch (event) {
      case BonsoirDiscoveryServiceFoundEvent():
        {
          event.service.resolve(
            _discovery.serviceResolver,
          ); // Should be called when the user wants to connect to this service.
        }
        break;
      case BonsoirDiscoveryServiceResolvedEvent():
        {
          String host = event.service.host ?? 'UNKNOWN';
          final discovered = MdnsDiscoveredDevice(
            host: host,
            port: event.service.port,
            serviceType: event.service.type,
            name: event.service.name,
            txt: event.service.attributes,
          );
          _eventBus.fire(FoundDeviceEvent(discovered));
        }
        break;
      case BonsoirDiscoveryServiceUpdatedEvent():
        break;
      case BonsoirDiscoveryServiceLostEvent():
        break;
      default:
        break;
    }
  }

  @override
  String get serviceType => _serviceType;

  @override
  void dispose() {
    assert(_isStopped);
    if (!_isDisposed) {
      _eventSub?.cancel();
      _isDisposed = true;
    }
  }
}

final class NsdMdnsProvider implements IMdnsProvider {
  @override
  Future<IMdnsDiscovery> startDiscovery(String serviceType, EventBus eventBus, {CancellationToken? cancelToken}) async {
    BonsoirDiscovery discovery = BonsoirDiscovery(type: serviceType, printLogs: false);
    await discovery.initialize().asCancellable(cancelToken);
    return NsdMdnsDiscovery(discovery, serviceType, eventBus);
  }
}
