import 'dart:async';

import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:synchronized/synchronized.dart';

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
  static const Duration kLocalProbeTimeOut = Duration(seconds: 3);
  static const Duration kHeartbeatPollingInterval = Duration(seconds: 5);

  Timer? _timer;

  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isScanning = false;

  final Logger _logger;
  final IDriverRegistry _driverRegistry;
  final IMdnsProvider? mdnsProvider;
  final List<IMdnsDiscovery> _mdnsDiscoveryList = [];

  final Map<String, BoundDeviceDescriptor> _registeredDevices = {};
  final Map<String, IDriver> _activatedDrivers = {};
  final Map<String, BoundDevice> _boundDevices = {};
  final GlobalDevicesEventBus _events = GlobalDevicesEventBus();
  final Set<String> _pollIDList = {};
  final CancellationToken _heartbeatPollingTaskCancelToken =
      CancellationToken();
  final CancellationToken _masterCancelToken = CancellationToken();
  late final StreamSubscription<DeviceOfflineEvent> _deviceOfflineSub;
  late final StreamSubscription<FoundDeviceEvent> _foundDeviceEventSub;
  final Lock _deviceOpLock = Lock();

  @override
  bool get isInitialized => _isInitialized;

  @override
  GlobalDevicesEventBus get events => _events;

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
  }

  @override
  Future<void> start({CancellationToken? cancelToken}) async {
    _logger.i('Starting the device management kernel...');

    _startTimer();
    _isInitialized = true;
    _logger.i('Kernel has been started.');
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      if (isScanning) {
        stopDevicesScanning();
      }
      _masterCancelToken.cancel();
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
    if (!_registeredDevices.containsKey(deviceID)) {
      throw ArgumentError('Cannot found deviceID `$deviceID`', 'deviceID');
    }
    final bound = _boundDevices[deviceID];
    if (bound == null) {
      final dev = _registeredDevices[deviceID];
      throw DeviceNotBoundError(
          'Cannot found the bound ${dev!.device}', dev.device);
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
  Future<bool> tryBind(
    Device device,
    String driverID, {
    Duration? timeout,
    CancellationToken? cancelToken,
  }) async {
    if (isBound(device.id)) {
      return true;
    }
    _ensureStarted();
    assert(_registeredDevices.containsKey(device.id));
    try {
      await bind(device, driverID, cancelToken: cancelToken, timeout: timeout);
      return true;
    } on CancelledException catch (_) {
      _logger.w('Device($device) binding cancelled');
      return false;
    } on TimeoutException catch (_) {
      _logger.w('Probing device($device) timed out');
      return false;
    } on DeviceProbeError catch (_) {
      return false;
    } catch (e, stackTrace) {
      _logger.e('Kernel error: $e', error: e, stackTrace: stackTrace);
      events.fire(
          LoadingDriverFailedEvent(device, error: e, message: e.toString()));
      return false;
    }
  }

  @override
  Future<void> bind(Device device, String driverID,
      {Duration? timeout, CancellationToken? cancelToken}) async {
    await _deviceOpLock.synchronized(() async {
      _ensureStarted();
      assert(_registeredDevices.containsKey(device.id));
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
          .probe(device, _events, cancelToken: cancelToken)
          .timeout(timeout ?? kLocalProbeTimeOut);

      if (driverInitialized) {
        // Try to activate device
        final deviceEvents = DeviceEventBus();
        final wotDevice = await driver.createWotDevice(device, deviceEvents,
            cancelToken: cancelToken);
        final bound =
            BoundDevice(driverID, device, driver, wotDevice, deviceEvents);

        _boundDevices[device.id] = bound;

        if (!_pollIDList.contains(device.id) &&
            driverDesc.heartbeatMethod == HeartbeatMethod.poll) {
          _pollIDList.add(device.id);
        }
        _events.fire(DeviceBoundEvent(device));
      } else {
        throw DeviceProbeError("Failed to probe $device", device);
      }
    });
  }

  @override
  Future<void> unbind(String deviceID, {CancellationToken? cancelToken}) async {
    await _deviceOpLock.synchronized(() async {
      _ensureStarted();
      assert(_registeredDevices.containsKey(deviceID));
      final boundDevice = _boundDevices[deviceID];
      if (boundDevice != null) {
        await boundDevice.driver
            .remove(boundDevice.device, cancelToken: cancelToken);
        boundDevice.dispose();
        _boundDevices.remove(deviceID);
        _purgeUnusedDriver();
        _events.fire(DeviceRemovedEvent(boundDevice.device));
      }
      if (_pollIDList.contains(deviceID)) {
        _pollIDList.remove(deviceID);
      }
    });
  }

  @override
  Future<void> unbindAll({CancellationToken? cancelToken}) async {
    await _deviceOpLock.synchronized(() async {
      _ensureStarted();
      final futures =
          _boundDevices.keys.map((id) => unbind(id, cancelToken: cancelToken));
      await Future.wait(futures);
    });
  }

  void _startTimer() {
    assert(!_isDisposed);

    _timer ??= Timer.periodic(kHeartbeatPollingInterval, (_) {
      try {
        _heartbeatPollingPeriodicTask(cancelToken: _masterCancelToken);
      } catch (e, stackTrace) {
        _logger.e(e.toString(), error: e, stackTrace: stackTrace);
      }
    });
  }

  Future<bool> _tryDoHeartBeat(BoundDevice bd, Duration timeout) async {
    try {
      await bd.driver
          .heartbeat(bd.device, cancelToken: _heartbeatPollingTaskCancelToken)
          .timeout(timeout)
          .asCancellable(_heartbeatPollingTaskCancelToken);
      return true;
    } catch (e, stackTrace) {
      _logger.t("Failed to do heartbeat", error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _heartbeatPollingPeriodicTask(
      {CancellationToken? cancelToken}) async {
    if (!isInitialized) {
      return;
    }
    if (_deviceOpLock.locked) {
      _logger.t('Heartbeat polling skipped due to device operation lock.');
      return;
    }
    try {
      await _deviceOpLock.synchronized(() async {
        final futures = <Future<bool>>[];

        // BoundDevices
        {
          final devices = <BoundDevice>[];
          for (final bd in _boundDevices.values) {
            if (_pollIDList.contains(bd.device.id)) {
              futures.add(_tryDoHeartBeat(bd, kHeartbeatPollingInterval)
                  .asCancellable(_heartbeatPollingTaskCancelToken));
              devices.add(bd);
            }
          }

          _logger
              .i('Polling heartbeat for (${devices.length}) bound devices...');
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

        // UnboundDevices
        futures.clear();
        final unboundDeviceDescriptors = _registeredDevices.values
            .where((x) => !isBound(x.device.id))
            .toList();
        for (final descriptor in unboundDeviceDescriptors) {
          futures.add(tryBind(descriptor.device, descriptor.driverID,
              timeout: kLocalProbeTimeOut,
              cancelToken: _heartbeatPollingTaskCancelToken));
        }
        _logger.i(
            'Polling heartbeat for (${unboundDeviceDescriptors.length}) unbound devices...');
        final boundResults = await Future.wait(futures)
            .timeout(kHeartbeatPollingInterval)
            .asCancellable(_heartbeatPollingTaskCancelToken);
        for (int i = 0; i < boundResults.length; i++) {
          /*
      if (!boundResults[i]) {
        _logger
              .w('Failed to bind device()');
      }
            */
        }
      }, timeout: kHeartbeatPollingInterval).asCancellable(cancelToken);
    } catch (e, stackTrace) {
      _logger.w("Failed to do the heartbeat: $e",
          error: e, stackTrace: stackTrace);
    }
  }

  void _ensureStarted() {
    if (_isInitialized == false) {
      throw InvalidOperationException(
          message: 'The kernel has not been initialized!');
    }
    assert(!_isDisposed);
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
  Future<void> startDevicesScanning(
      {Duration? timeout, CancellationToken? cancelToken}) async {
    assert(!_isScanning);
    _isScanning = true;
    await _startMdnsDiscovery(
        cancelToken: MergedCancellationToken(
            [if (cancelToken != null) cancelToken, _masterCancelToken]));
    _events.fire(DeviceDiscoveringStartedEvent());

    if (timeout != null) {
      Future.delayed(timeout, stopDevicesScanning).asCancellable(cancelToken);
    }
  }

  @override
  Future<void> stopDevicesScanning({CancellationToken? cancelToken}) async {
    assert(_isScanning);
    try {
      await _stopMdnsDiscovery().asCancellable(MergedCancellationToken(
          [if (cancelToken != null) cancelToken, _masterCancelToken]));
    } finally {
      _isScanning = false;
      _events.fire(DeviceDiscoveringStoppedEvent());
      _logger.i('Devices scanning stopped.');
    }
  }

  Future<void> _startMdnsDiscovery({CancellationToken? cancelToken}) async {
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
                .startDiscovery(mdnsMethod.serviceType, _events,
                    cancelToken: cancelToken)
                .asCancellable(cancelToken);
            allSupportedMdnsServiceTypes.add(mdnsMethod.serviceType);
            _mdnsDiscoveryList.add(discovery);
          }
        }
      }
    }
  }

  Future<void> _stopMdnsDiscovery({CancellationToken? cancelToken}) async {
    if (mdnsProvider != null) {
      for (final disc in _mdnsDiscoveryList) {
        await disc.stop().asCancellable(cancelToken);
        disc.dispose();
      }
      _mdnsDiscoveryList.clear();
    }
  }

  @override
  void registerDevice(BoundDeviceDescriptor device) {
    _registeredDevices[device.device.id] = device;
  }

  @override
  void registerDevices(Iterable<BoundDeviceDescriptor> devices) {
    for (final d in devices) {
      _registeredDevices[d.device.id] = d;
    }
  }

  @override
  void unregisterDevice(String deviceID) {
    _registeredDevices.remove(deviceID);
  }

  @override
  void unregisterAllDevices() {
    _registeredDevices.clear();
  }
}
