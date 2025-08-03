import 'dart:async';

import 'package:borneo_kernel/drivers/borneo/lyfi/coap_driver.dart';
import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:synchronized/synchronized.dart';
import 'package:retry/retry.dart';

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
  static const Duration kStartupDiscoveryDuration = Duration(seconds: 15);
  static const Duration kLocalProbeTimeOut = Duration(seconds: 10);
  static const Duration kLocalBindTimeOut = Duration(seconds: 30);
  static const Duration kHeartbeatPollingInterval = Duration(seconds: 15);

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
  final Map<String, StreamSubscription> _deviceEventRouters = {};
  final GlobalDevicesEventBus _events = GlobalDevicesEventBus();
  final Set<String> _pollIDList = {};
  final CancellationToken _heartbeatPollingTaskCancelToken = CancellationToken();
  final CancellationToken _masterCancelToken = CancellationToken();
  late final StreamSubscription<DeviceOfflineEvent> _deviceOfflineSub;
  late final StreamSubscription<FoundDeviceEvent> _foundDeviceEventSub;
  final Lock _deviceOpLock = Lock();
  final Lock _hbLock = Lock();
  final Map<String, int> _consecutiveFailures = {};
  final Map<String, StreamSubscription> _observationSubscriptions = {};
  final Map<String, int> _missedObservations = {};
  final Map<String, Timer> _observationTimeoutTimers = {};
  static const int kMaxMissedObservations = 3;

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

    _deviceOfflineSub = _events.on<DeviceOfflineEvent>().listen((event) async {
      try {
        await unbind(event.device.id);
      } catch (e, stackTrace) {
        _logger.e('Failed to unbind offline device ${event.device.id}: $e', error: e, stackTrace: stackTrace);
      }
    });

    _foundDeviceEventSub = _events.on<FoundDeviceEvent>().listen(_onDeviceFound);
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
      _isDisposed = true;

      if (isScanning) {
        _isScanning = false;
        if (mdnsProvider != null) {
          for (final disc in _mdnsDiscoveryList) {
            disc.dispose();
          }
          _mdnsDiscoveryList.clear();
        }
      }

      _masterCancelToken.cancel();
      _timer?.cancel();
      _heartbeatPollingTaskCancelToken.cancel();

      _deviceOfflineSub.cancel();
      _foundDeviceEventSub.cancel();

      for (final subscription in _observationSubscriptions.values) {
        subscription.cancel();
      }
      _observationSubscriptions.clear();

      for (final timer in _observationTimeoutTimers.values) {
        timer.cancel();
      }
      _observationTimeoutTimers.clear();

      for (final deviceEventRouter in _deviceEventRouters.values) {
        deviceEventRouter.cancel();
      }
      _deviceEventRouters.clear();

      for (final boundDevice in _boundDevices.values) {
        boundDevice.dispose();
      }
      _boundDevices.clear();

      for (final driver in _activatedDrivers.values) {
        driver.dispose();
      }
      _activatedDrivers.clear();

      _events.destroy();
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
      throw DeviceNotBoundError('Cannot found the bound ${dev!.device}', dev.device);
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
  Future<bool> tryBind(Device device, String driverID, {CancellationToken? cancelToken}) async {
    if (isBound(device.id)) {
      return true;
    }
    _ensureStarted();
    assert(_registeredDevices.containsKey(device.id));
    try {
      await bind(device, driverID, cancelToken: cancelToken);
      return true;
    } on CancelledException catch (_) {
      _logger.w('Device($device) binding cancelled');
      return false;
    } on TimeoutException catch (error, stackTrace) {
      _logger.w('Probing device($device) timed out:', error: error, stackTrace: stackTrace);
      return false;
    } on DeviceProbeError catch (_) {
      return false;
    } catch (e, stackTrace) {
      _logger.e('Kernel error: $e', error: e, stackTrace: stackTrace);
      events.fire(LoadingDriverFailedEvent(device, error: e, message: e.toString()));
      return false;
    }
  }

  @override
  Future<void> bind(Device device, String driverID, {CancellationToken? cancelToken}) async {
    cancelToken?.throwIfCancelled();
    final eventsToFire = [];

    await _deviceOpLock.synchronized(() async {
      _ensureStarted();

      cancelToken?.throwIfCancelled();

      assert(_registeredDevices.containsKey(device.id));
      _logger.i('Binding device: `$device` to driver `$driverID`');
      var driverDesc = _driverRegistry.metaDrivers[driverID];
      if (driverDesc == null) {
        final msg = 'Failed to find the driver key `$driverID` for device(`${device.address}`)';
        _logger.e(msg);
        throw ArgumentError(msg, 'device');
      }
      // Load unused the driver
      final driver = _ensureDriverActivated(driverID);

      final driverInitialized = await driver.probe(device, cancelToken: cancelToken);

      if (driverInitialized) {
        // Try to activate device
        final bound = BoundDevice(driverID, device, driver);
        _deviceEventRouters[device.id] = bound.device.driverData.deviceEvents.on().listen((event) {
          _events.fire(event);
        });

        //_events.fire(DeviceBoundEvent(device));
        eventsToFire.add(DeviceBoundEvent(device));

        // Start observation for push heartbeat if supported
        final driverDesc = _driverRegistry.metaDrivers[driverID];
        if (driverDesc?.heartbeatMethod == HeartbeatMethod.push) {
          await _startHeartbeatObservation(device, driver);
        }
        _boundDevices[device.id] = bound;

        if (!_pollIDList.contains(device.id) && driverDesc!.heartbeatMethod == HeartbeatMethod.poll) {
          _pollIDList.add(device.id);
        }
      } else {
        throw DeviceProbeError("Failed to probe $device", device);
      }
    }, timeout: kLocalBindTimeOut);
    for (final e in eventsToFire) {
      _events.fire(e);
    }
  }

  @override
  Future<void> unbind(String deviceID, {CancellationToken? cancelToken}) async {
    await _deviceOpLock.synchronized(() async {
      _ensureStarted();
      assert(_registeredDevices.containsKey(deviceID));
      final boundDevice = _boundDevices[deviceID];
      if (boundDevice != null) {
        await boundDevice.driver.remove(boundDevice.device, cancelToken: cancelToken);
        boundDevice.dispose();
        _boundDevices.remove(deviceID);

        _deviceEventRouters[deviceID]?.cancel();
        _deviceEventRouters.remove(deviceID);

        // Clean up consecutive failures tracking
        _consecutiveFailures.remove(deviceID);

        // Clean up heartbeat observation
        await _stopHeartbeatObservation(deviceID);

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
      final deviceIds = List.from(_boundDevices.keys); // 复制列表避免并发修改
      for (final deviceId in deviceIds) {
        // 直接在锁内执行解绑逻辑，避免重复获取锁
        final boundDevice = _boundDevices[deviceId];
        if (boundDevice != null) {
          await boundDevice.driver.remove(boundDevice.device, cancelToken: cancelToken);
          boundDevice.dispose();
          _boundDevices.remove(deviceId);

          _deviceEventRouters[deviceId]?.cancel();
          _deviceEventRouters.remove(deviceId);

          // Clean up consecutive failures tracking
          _consecutiveFailures.remove(deviceId);

          if (_pollIDList.contains(deviceId)) {
            _pollIDList.remove(deviceId);
          }

          _events.fire(DeviceRemovedEvent(boundDevice.device));
        }
      }
      _purgeUnusedDriver();
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
      final result = await retry(
        () async {
          final success = await bd.driver
              .heartbeat(bd.device, cancelToken: _heartbeatPollingTaskCancelToken)
              .timeout(timeout)
              .asCancellable(_heartbeatPollingTaskCancelToken);
          if (!success) {
            throw Exception('Heartbeat failed');
          }
          return success;
        },
        maxAttempts: 3,
        delayFactor: const Duration(milliseconds: 500),
        maxDelay: const Duration(seconds: 1),
        randomizationFactor: 0.1,
      );
      return result;
    } catch (e, stackTrace) {
      _logger.t("Failed to do heartbeat after retries", error: e, stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> _startHeartbeatObservation(Device device, IDriver driver) async {
    try {
      // Check if the driver supports observation (has observation method)
      if (driver is! BorneoLyfiCoapDriver) {
        _logger.w('Driver ${driver.runtimeType} does not support push heartbeat observation');
        return;
      }

      final deviceId = device.id;

      // Clean up any existing observation
      await _stopHeartbeatObservation(deviceId);

      _logger.d('Starting heartbeat observation for device $deviceId');

      // Start observation
      final obsStream = await driver.startHeartbeatObservation(device);

      _observationSubscriptions[deviceId] = obsStream.listen(
        (timestamp) {
          _onHeartbeatReceived(deviceId, timestamp);
        },
        onError: (error) {
          if (error.toString().contains('CoapRequestException') || error.toString().contains('timed out')) {
            _logger.w('Heartbeat observation error for device $deviceId: $error');
            _onHeartbeatMissed(device.id);
          } else {
            _logger.e('Unknown heartbeat observation error for device $deviceId: $error');
          }
          _onHeartbeatMissed(deviceId);
        },
        onDone: () {
          _logger.w('Heartbeat observation ended for device $deviceId');
          _onHeartbeatMissed(deviceId);
        },
        cancelOnError: false,
      );

      // Reset missed observations counter
      _missedObservations[deviceId] = 0;

      // Set up timeout timer
      _resetObservationTimeout(deviceId);
    } catch (e, stackTrace) {
      _logger.e('Failed to start heartbeat observation for device ${device.id}', error: e, stackTrace: stackTrace);
    }
  }

  void _onHeartbeatReceived(String deviceId, dynamic timestamp) {
    _logger.d('Heartbeat received for device $deviceId: $timestamp');

    // Reset missed observations counter
    _missedObservations[deviceId] = 0;

    // Reset timeout timer
    _resetObservationTimeout(deviceId);
  }

  void _onHeartbeatMissed(String deviceId) {
    _missedObservations[deviceId] = (_missedObservations[deviceId] ?? 0) + 1;
    _logger.w('Heartbeat missed for device $deviceId. Total missed: ${_missedObservations[deviceId]}');

    if (_missedObservations[deviceId]! >= kMaxMissedObservations) {
      _logger.w('Device $deviceId marked offline after $kMaxMissedObservations missed observations');

      // Find the device and mark it offline
      final boundDevice = _boundDevices[deviceId];
      if (boundDevice != null) {
        _events.fire(DeviceOfflineEvent(boundDevice.device));
      }

      // Clean up observation
      _stopHeartbeatObservation(deviceId);
    } else {
      // Reset timeout timer for next observation
      _resetObservationTimeout(deviceId);
    }
  }

  void _resetObservationTimeout(String deviceId) {
    _observationTimeoutTimers[deviceId]?.cancel();

    // Set timeout for 3x the normal heartbeat interval
    _observationTimeoutTimers[deviceId] = Timer(kHeartbeatPollingInterval * 3, () => _onHeartbeatMissed(deviceId));
  }

  Future<void> _stopHeartbeatObservation(String deviceId) async {
    _observationSubscriptions[deviceId]?.cancel();
    _observationSubscriptions.remove(deviceId);

    _observationTimeoutTimers[deviceId]?.cancel();
    _observationTimeoutTimers.remove(deviceId);

    _missedObservations.remove(deviceId);
  }

  Future<void> _heartbeatPollingPeriodicTask({CancellationToken? cancelToken}) async {
    if (!isInitialized) {
      return;
    }
    if (_hbLock.locked) {
      _logger.t('Heartbeat polling skipped due to device operation lock.');
      return;
    }

    final List<Device> offlineDevices = [];

    try {
      await _hbLock
          .synchronized(() async {
            final futures = <Future<bool>>[];

            // BoundDevices - only poll devices that use HeartbeatMethod.poll
            {
              final devices = <BoundDevice>[];
              for (final bd in _boundDevices.values) {
                final driverDesc = _driverRegistry.metaDrivers[bd.driverID];
                if (driverDesc?.heartbeatMethod == HeartbeatMethod.poll) {
                  futures.add(
                    _tryDoHeartBeat(bd, kHeartbeatPollingInterval).asCancellable(_heartbeatPollingTaskCancelToken),
                  );
                  devices.add(bd);
                }
              }

              _logger.d('Polling heartbeat for (${devices.length}) bound devices...');
              final results = await Future.wait(
                futures,
              ).timeout(kHeartbeatPollingInterval).asCancellable(_heartbeatPollingTaskCancelToken);
              for (int i = 0; i < results.length; i++) {
                final deviceId = devices[i].device.id;
                if (!results[i]) {
                  _consecutiveFailures[deviceId] = (_consecutiveFailures[deviceId] ?? 0) + 1;
                  _logger.w(
                    'The device(${devices[i].device}) is not responding. Consecutive failures: ${_consecutiveFailures[deviceId]}',
                  );

                  // Only mark as offline after 3 consecutive failures
                  if (_consecutiveFailures[deviceId]! >= 3) {
                    offlineDevices.add(devices[i].device);
                    _consecutiveFailures.remove(deviceId);
                  }
                } else {
                  // Reset consecutive failures on success
                  _consecutiveFailures.remove(deviceId);
                }
              }
            }

            // UnboundDevices
            futures.clear();
            final unboundDeviceDescriptors = _registeredDevices.values.where((x) => !isBound(x.device.id)).toList();
            for (final descriptor in unboundDeviceDescriptors) {
              futures.add(
                tryBind(descriptor.device, descriptor.driverID, cancelToken: _heartbeatPollingTaskCancelToken),
              );
            }
            _logger.d('Polling heartbeat for (${unboundDeviceDescriptors.length}) unbound devices...');
            final boundResults = await Future.wait(futures).asCancellable(_heartbeatPollingTaskCancelToken);
            for (int i = 0; i < boundResults.length; i++) {
              /*
      if (!boundResults[i]) {
        _logger
              .w('Failed to bind device()');
      }
            */
            }
          })
          .asCancellable(cancelToken);
    } catch (e, stackTrace) {
      _logger.w("Failed to do the heartbeat: $e", error: e, stackTrace: stackTrace);
    }

    // 在锁外处理离线设备
    for (final device in offlineDevices) {
      if (!_isDisposed) {
        _events.fire(DeviceOfflineEvent(device));
      }
    }
  }

  void _ensureStarted() {
    if (_isInitialized == false) {
      throw InvalidOperationException(message: 'The kernel has not been initialized!');
    }
    assert(!_isDisposed);
  }

  IDriver _ensureDriverActivated(String driverID) {
    var driverDesc = _driverRegistry.metaDrivers[driverID]!;
    if (!_activatedDrivers.containsKey(driverID)) {
      _activatedDrivers[driverID] = driverDesc.factory(logger: _logger);
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
      'Found mDNS service: , name=`${event.discovered.name}`, host=`${event.discovered.host}`, port=`${event.discovered.port}`',
    );
    final matched = _matchesDriver(event.discovered);
    if (matched != null) {
      if (!_boundDevices.values.any((x) => x.device.fingerprint == matched.fingerprint)) {
        _logger.i('Unbound device found: `${matched.address}`');
        _events.fire(UnboundDeviceDiscoveredEvent(matched));
      }
    }
  }

  @override
  Future<void> startDevicesScanning({Duration? timeout, CancellationToken? cancelToken}) async {
    assert(!_isScanning);
    _isScanning = true;
    await _startMdnsDiscovery(
      cancelToken: MergedCancellationToken([if (cancelToken != null) cancelToken, _masterCancelToken]),
    );
    _events.fire(DeviceDiscoveringStartedEvent());

    if (timeout != null) {
      Future.delayed(timeout, stopDevicesScanning).asCancellable(cancelToken);
    }
  }

  @override
  Future<void> stopDevicesScanning({CancellationToken? cancelToken}) async {
    assert(_isScanning);
    try {
      await _stopMdnsDiscovery().asCancellable(
        MergedCancellationToken([if (cancelToken != null) cancelToken, _masterCancelToken]),
      );
      _isScanning = false;
      if (!_isDisposed) {
        _events.fire(DeviceDiscoveringStoppedEvent());
      }
      _logger.i('Devices scanning stopped.');
    } catch (e) {
      _isScanning = false;
      _logger.e('Error stopping device scanning: $e');
      rethrow;
    }
  }

  Future<void> _startMdnsDiscovery({CancellationToken? cancelToken}) async {
    if (mdnsProvider != null) {
      // TODO error handling
      final Set<String> allSupportedMdnsServiceTypes = {};
      for (final metaDriver in _driverRegistry.metaDrivers.values) {
        if (metaDriver.discoveryMethod is MdnsDeviceDiscoveryMethod) {
          final mdnsMethod = metaDriver.discoveryMethod as MdnsDeviceDiscoveryMethod;
          if (!allSupportedMdnsServiceTypes.contains(mdnsMethod.serviceType)) {
            _logger.i('Starting mDNS discovery for service type `${mdnsMethod.serviceType}`...');
            final discovery = await mdnsProvider!.startDiscovery(
              mdnsMethod.serviceType,
              _events,
              cancelToken: MergedCancellationToken([if (cancelToken != null) cancelToken, _masterCancelToken]),
            );
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
        await disc.stop(cancelToken: cancelToken);
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
