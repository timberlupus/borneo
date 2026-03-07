import 'dart:async';

import 'package:borneo_kernel_abstractions/models/driver_descriptor.dart';
import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';

import 'package:borneo_kernel_abstractions/discovery_manager.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';
import 'package:borneo_kernel_abstractions/mdns.dart';
import 'package:borneo_kernel_abstractions/driver_registry.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/event_dispatcher.dart';
import 'package:borneo_kernel_abstractions/device_bus.dart';
import 'package:event_bus/event_bus.dart';

/// Default implementation of [DiscoveryManager] that currently only supports
/// mDNS discovery.  This class encapsulates the previous mDNS logic that used
/// to live inside [DefaultKernel] and exposes a simple stream of
/// [DiscoveredDevice].
///
/// In the future this may aggregate multiple [DeviceBus] implementations.
class DefaultDiscoveryManager implements DiscoveryManager {
  final Logger _logger;
  final IDriverRegistry _driverRegistry;
  final IMdnsProvider? mdnsProvider;
  final EventDispatcher _events;

  bool _active = false;
  bool _disposed = false;

  /// Registered discovery buses.  We use a map so unregistration can be
  /// performed by id.
  final Map<String, DeviceBus> _buses = {};
  final Map<String, List<StreamSubscription<dynamic>>> _busSubscriptions = {};

  final StreamController<DiscoveredDevice> _foundCtrl = StreamController.broadcast();
  final StreamController<DiscoveredDevice> _lostCtrl = StreamController.broadcast();

  DefaultDiscoveryManager(this._logger, this._driverRegistry, this._events, {this.mdnsProvider}) {
    // register built‑in mDNS bus if provider is available
    if (mdnsProvider != null) {
      registerBus(_MdnsBus(mdnsProvider!, _driverRegistry, _logger));
    }
  }

  @override
  Stream<DiscoveredDevice> get onDeviceFound => _foundCtrl.stream;

  @override
  Stream<DiscoveredDevice> get onDeviceLost => _lostCtrl.stream;

  @override
  bool get isActive => _active;

  @override
  Future<void> start({Duration? timeout, CancellationToken? cancelToken}) async {
    if (_disposed || _active) return;
    _active = true;

    // start every registered bus in parallel
    await Future.wait(_buses.values.map((b) => b.start()));

    if (timeout != null) {
      Future.delayed(timeout, () {
        stop(cancelToken: cancelToken);
      });
    }
  }

  @override
  Future<void> stop({CancellationToken? cancelToken}) async {
    if (!_active) return;
    _active = false;
    await Future.wait(_buses.values.map((b) => b.stop()));
  }

  @override
  void registerBus(DeviceBus bus) {
    if (_disposed || _buses.containsKey(bus.id)) return;
    _buses[bus.id] = bus;

    // forward events from bus to our controllers and also fire kernel events
    final foundSub = bus.onDeviceFound.listen((d) {
      if (_disposed) return;
      _foundCtrl.add(d);
      _events.fire(FoundDeviceEvent(d));
    });
    final lostSub = bus.onDeviceLost.listen((device) {
      if (_disposed) return;
      _lostCtrl.add(device);
    });
    _busSubscriptions[bus.id] = [foundSub, lostSub];

    if (_active) {
      // start immediately if already active
      unawaited(bus.start());
    }
  }

  @override
  void unregisterBus(String busId) {
    final bus = _buses.remove(busId);
    final subscriptions = _busSubscriptions.remove(busId);
    if (subscriptions != null) {
      unawaited(Future.wait(subscriptions.map((sub) => sub.cancel())));
    }
    if (bus != null && _active) {
      unawaited(bus.stop());
    }
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _active = false;

    unawaited(Future.wait(_buses.values.map((bus) => bus.stop())));

    for (final subscriptions in _busSubscriptions.values) {
      unawaited(Future.wait(subscriptions.map((sub) => sub.cancel())));
    }

    _busSubscriptions.clear();
    _buses.clear();
    _foundCtrl.close();
    _lostCtrl.close();
  }
}

/// Simple DeviceBus implementation wrapping an [IMdnsProvider].
class _MdnsBus implements DeviceBus {
  final IMdnsProvider _provider;
  final IDriverRegistry _driverRegistry;
  final Logger _logger;

  final EventBus _bus = EventBus();
  bool _started = false;
  final List<IMdnsDiscovery> _discoveries = [];

  final StreamController<DiscoveredDevice> _found = StreamController.broadcast();
  final StreamController<DiscoveredDevice> _lost = StreamController.broadcast();

  _MdnsBus(this._provider, this._driverRegistry, this._logger) {
    _bus.on<FoundDeviceEvent>().listen((e) {
      _found.add(e.discovered);
    });
    _bus.on<LostDeviceEvent>().listen((e) {
      _lost.add(e.discovered);
    });
  }

  @override
  String get id => 'mdns';

  @override
  Stream<DiscoveredDevice> get onDeviceFound => _found.stream;

  @override
  Stream<DiscoveredDevice> get onDeviceLost => _lost.stream;

  @override
  Future<void> start() async {
    if (_started) return;
    _started = true;
    final Set<String> allSupportedMdnsServiceTypes = {};
    for (final metaDriver in _driverRegistry.metaDrivers.values) {
      if (metaDriver.discoveryMethod case MdnsDeviceDiscoveryMethod mdnsMethod) {
        if (!allSupportedMdnsServiceTypes.contains(mdnsMethod.serviceType)) {
          _logger.i('[_MdnsBus] starting discovery for ');
          final discovery = await _provider.startDiscovery(mdnsMethod.serviceType, _bus);
          allSupportedMdnsServiceTypes.add(mdnsMethod.serviceType);
          _discoveries.add(discovery);
        }
      }
    }
  }

  @override
  Future<void> stop() async {
    if (!_started) return;
    _started = false;
    for (final disc in _discoveries) {
      await disc.stop();
      disc.dispose();
    }
    _discoveries.clear();
  }

  @override
  Future<void> connect(String deviceId) async {}

  @override
  Future<void> disconnect(String deviceId) async {}
}
