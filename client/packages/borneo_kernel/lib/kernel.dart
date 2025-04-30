import 'dart:async';

import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:borneo_kernel_abstractions/idriver_registry.dart';
import 'package:borneo_kernel_abstractions/ikernel.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_kernel_abstractions/models/discovered_device.dart';
import 'package:borneo_kernel_abstractions/models/driver_descriptor.dart';
import 'package:borneo_kernel_abstractions/mdns.dart';

final class DefaultKernel implements IKernel {
  static const Duration kStartupDiscoveryDuration = Duration(seconds: 10);
  static const Duration kProbeTimeOut = Duration(seconds: 3);
  static const Duration kHeartbeatPollingInterval = Duration(seconds: 5);

  Timer? _timer;

  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isScanning = false;

  final Logger _logger;
  final IDriverRegistry _driverRegistry;
  final IMdnsProvider? mdnsProvider;
  final List<IMdnsDiscovery> _mdnsDiscoveryList = [];

  final Map<String, IDriver> _activatedDrivers = {};
  final Map<String, BoundDevice> _boundDevices = {};
  final EventBus _events = EventBus();
  final Set<String> _pollIDList = {};
  final CancellationToken _heartbeatPollingTaskCancelToken =
      CancellationToken();
  final CancellationToken _mdnsCancelToken = CancellationToken();
  late final StreamSubscription<DeviceOfflineEvent> _deviceOfflineSub;
  late final StreamSubscription<FoundDeviceEvent> _foundDeviceEventSub;

  @override
  bool get isInitialized => _isInitialized;

  @override
  EventBus get events => _events;

  @override
  Iterable<IDriver> get activatedDrivers => _activatedDrivers.values;

  @override
  Iterable<BoundDevice> get boundDevices => _boundDevices.values;

  @override
  bool get isScanning => _isScanning;

  DefaultKernel(this._logger, this._driverRegistry, {this.mdnsProvider}) {
    _logger.i('Loading the kernel...');

    _deviceOfflineSub = _events
        .on<DeviceOfflineEvent>()
        .listen((event) async => await unbind(event.device.id));

    _foundDeviceEventSub =
        _events.on<FoundDeviceEvent>().listen(_onDeviceFound);

    //_startTimer();
  }

  @override
  Future<void> start() async {
    _logger.i('Starting the device management kernel...');

    _isInitialized = true;
    _logger.i('Kernel has been started.');
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      if (isScanning) {
        stopDevicesScanning();
      }
      _timer?.cancel();
      _deviceOfflineSub.cancel();
      _foundDeviceEventSub.cancel();
      _heartbeatPollingTaskCancelToken.cancel();
      _events.destroy();
      _isDisposed = true;
    }
  }

  @override
  BoundDevice getBoundDevice(String deviceID) {
    _ensureStarted();
    if (deviceID.isEmpty) {
      throw ArgumentError('`deviceID` cannnot be empty.', 'deviceID');
    }
    final bound = _boundDevices[deviceID];
    if (bound == null) {
      throw DeviceNotBoundError(
          'Cannot found the bound device(id=`$deviceID`)', deviceID);
    }
    return bound;
  }

  @override
  bool isBound(String deviceID) {
    _ensureStarted();
    if (deviceID.isEmpty) {
      throw ArgumentError('`deviceID` cannnot be empty.', 'deviceID');
    }
    return _boundDevices.containsKey(deviceID);
  }

  SupportedDeviceDescriptor? _matchesDriver(DiscoveredDevice discovered) {
    _ensureStarted();
    for (var meta in _driverRegistry.metaDrivers.values) {
      final matched = meta.matches(discovered);
      if (matched != null) {
        return matched;
      }
    }
    return null;
  }

  @override
  Future<bool> tryBind(Device device, String driverID, {cancelToken}) async {
    _ensureStarted();
    try {
      await bind(device, driverID, cancelToken: cancelToken);
      return true;
    } on CancelledException catch (_) {
      _logger.w('Device($device) binding cancelled');
      return false;
    } on TimeoutException catch (_) {
      _logger.w('Probing device($device) timed out');
      return false;
    } catch (e, stackTrace) {
      _logger.e('Kernel error: $e', error: e, stackTrace: stackTrace);
      events.fire(
          LoadingDriverFailedEvent(device, error: e, message: e.toString()));
      return false;
    }
  }

  @override
  Future<void> bind(Device device, String driverID, {cancelToken}) async {
    _ensureStarted();
    _logger.i('Binding device: `$device` to driver `$driverID`');
    var driverDesc = _driverRegistry.metaDrivers[driverID];
    if (driverDesc == null) {
      final msg =
          'Failed to find the driver key `$driverID` for device(`${device.address}`)';
      _logger.e(msg);
      throw ArgumentError(msg, 'device');
    }
    // Load unused the driver
    final driver = _ensureDriverActivated(driverID);

    final driverInitialized = await driver
        .probe(device)
        .timeout(kProbeTimeOut)
        .asCancellable(cancelToken);

    if (driverInitialized) {
      // Try to activate device
      final bound = BoundDevice(driverID, device, driver);
      _boundDevices[device.id] = bound;

      if (!_pollIDList.contains(device.id) &&
          driverDesc.heartbeatMethod == HeartbeatMethod.poll) {
        _pollIDList.add(device.id);
      }
      _events.fire(DeviceBoundEvent(device));
    } else {
      final msg = "Failed to probe device: $device";
      _logger.e(msg);
      throw InvalidOperationException(message: msg);
    }
  }

  @override
  Future<void> unbind(String deviceID) async {
    _ensureStarted();
    final boundDevice = _boundDevices[deviceID];
    if (boundDevice != null) {
      boundDevice.dispose();
      await boundDevice.driver.remove(boundDevice.device);
      _boundDevices.remove(deviceID);
      _purgeUnusedDriver();
      _events.fire(DeviceRemovedEvent(boundDevice.device));
    }
    if (_pollIDList.contains(deviceID)) {
      _pollIDList.remove(deviceID);
    }
  }

  @override
  Future<void> unbindAll({cancelToken}) async {
    _ensureStarted();
    final futures = _boundDevices.keys.map((id) => unbind(id));
    await Future.wait(futures);
  }

  void _startTimer() {
    assert(!_isDisposed);

    if (_timer != null) {
      _timer = Timer.periodic(
        kHeartbeatPollingInterval,
        (_) => _heartbeatPollingPeriodicTask()
            .asCancellable(_heartbeatPollingTaskCancelToken),
      );
    }
  }

  Future<void> _heartbeatPollingPeriodicTask() async {
    if (!isInitialized) {
      return;
    }
    final futures = <Future<bool>>[];
    final devices = <BoundDevice>[];
    for (final bd in _boundDevices.values) {
      if (_pollIDList.contains(bd.device.id)) {
        futures.add(bd.driver
            .heartbeat(bd.device)
            .timeout(kProbeTimeOut, onTimeout: () => false)
            .asCancellable(_heartbeatPollingTaskCancelToken));
        devices.add(bd);
      }
    }
    _logger.i('Polling heartbeat for (${devices.length}) devices...');
    final results = await Future.wait(futures)
        .timeout(kHeartbeatPollingInterval)
        .asCancellable(_heartbeatPollingTaskCancelToken);
    for (int i = 0; i < results.length; i++) {
      if (!results[i]) {
        _logger.w('The device(${devices[i].device}) is not responding.');
        _events.fire(DeviceOfflineEvent(devices[i].device));
      }
    }
  }

  void _ensureStarted() {
    if (_isInitialized == false) {
      throw InvalidOperationException(
          message: 'The kernel has not been initialized!');
    }
  }

  IDriver _ensureDriverActivated(String driverID) {
    var driverDesc = _driverRegistry.metaDrivers[driverID]!;
    if (!_activatedDrivers.containsKey(driverID)) {
      _activatedDrivers[driverID] = driverDesc.factory();
    }
    _purgeUnusedDriver(newDriverID: driverID);
    return _activatedDrivers[driverID]!;
  }

  void _purgeUnusedDriver({String? newDriverID}) {
    _ensureStarted();
    final boundKeys = Set.from(_boundDevices.values.map((x) => x.driverID));
    final activatedKeys = Set.from(_activatedDrivers.keys);
    final keysToRemove = activatedKeys.difference(boundKeys);
    if (newDriverID != null && keysToRemove.contains(newDriverID)) {
      keysToRemove.remove(newDriverID);
    }
    for (final k in keysToRemove) {
      final driver = _activatedDrivers[k]!;
      driver.dispose();
      _activatedDrivers.remove(k);
    }
  }

  void _onDeviceFound(FoundDeviceEvent event) {
    _ensureStarted();
    _logger.d(
        'Found mDNS service: , name=`${event.discovered.name}`, host=`${event.discovered.host}`, port=`${event.discovered.port}`');
    final matched = _matchesDriver(event.discovered);
    if (matched != null) {
      if (!_boundDevices.values
          .any((x) => x.device.fingerprint == matched.fingerprint)) {
        _logger.i('Unbound device found: `${matched.address}`');
        _events.fire(UnboundDeviceDiscoveredEvent(
          matched,
        ));
      }
    }
  }

  @override
  Future<void> startDevicesScanning({Duration? timeout}) async {
    assert(!_isScanning);
    _isScanning = true;
    await _startMdnsDiscovery();
    _events.fire(DeviceDiscoveringStartedEvent());

    if (timeout != null) {
      Future.delayed(timeout, stopDevicesScanning);
    }
  }

  @override
  Future<void> stopDevicesScanning() async {
    assert(_isScanning);
    try {
      await _stopMdnsDiscovery();
    } finally {
      _isScanning = false;
      _events.fire(DeviceDiscoveringStoppedEvent());
      _logger.i('Devices scanning stopped.');
    }
  }

  Future<void> _startMdnsDiscovery() async {
    if (mdnsProvider != null) {
      // TODO error handling
      final Set<String> allSupportedMdnsServiceTypes = {};
      for (final metaDriver in _driverRegistry.metaDrivers.values) {
        if (metaDriver.discoveryMethod is MdnsDeviceDiscoveryMethod) {
          final mdnsMethod =
              metaDriver.discoveryMethod as MdnsDeviceDiscoveryMethod;
          if (!allSupportedMdnsServiceTypes.contains(mdnsMethod.serviceType)) {
            _logger.i(
                'Starting mDNS discovery for service type `${mdnsMethod.serviceType}`...');
            final discovery = await mdnsProvider!
                .startDiscovery(mdnsMethod.serviceType, _events)
                .asCancellable(_mdnsCancelToken);
            allSupportedMdnsServiceTypes.add(mdnsMethod.serviceType);
            _mdnsDiscoveryList.add(discovery);
          }
        }
      }
    }
  }

  Future<void> _stopMdnsDiscovery() async {
    if (mdnsProvider != null) {
      for (final disc in _mdnsDiscoveryList) {
        await disc.stop();
        disc.dispose();
      }
      _mdnsDiscoveryList.clear();
    }
  }
}
