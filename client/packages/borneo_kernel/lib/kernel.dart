import 'dart:async';

import 'package:borneo_kernel/drivers/borneo/lyfi/coap_driver.dart';
import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:synchronized/synchronized.dart';
import 'package:retry/retry.dart';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'discovery_manager_impl.dart';
import 'binding_engine_impl.dart';

export 'binding_engine_impl.dart';

final class DefaultKernel implements IKernel {
  static const Duration kStartupDiscoveryDuration = Duration(seconds: 15);

  // Configurable heartbeat / probe parameters. Defaults chosen to detect
  // disconnects faster while remaining conservative for flaky networks.
  final Duration localProbeTimeout;
  final Duration localBindTimeout;
  final Duration heartbeatPollingInterval;
  final int maxMissedObservations;
  final int consecutiveFailureThreshold;
  final int heartbeatRetryMaxAttempts;
  final int observationTimeoutMultiplier;

  Timer? _timer;

  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isScanning = false;

  // When true the periodic _heartbeatPollingPeriodicTask should do nothing.
  bool _heartbeatSuspended = false;

  final Logger _logger;
  final IDriverRegistry _driverRegistry;
  final IMdnsProvider? mdnsProvider;
  late final DiscoveryManager _discoveryManager;
  late final BindingEngine _bindingEngine;

  final Map<String, BoundDeviceDescriptor> _registeredDevices = {};
  final GlobalDevicesEventBus _events = GlobalDevicesEventBus();
  final Set<String> _pollIDList = {};
  final CancellationToken _heartbeatPollingTaskCancelToken = CancellationToken();
  final CancellationToken _masterCancelToken = CancellationToken();
  late final StreamSubscription<DeviceOfflineEvent> _deviceOfflineSub;
  late final StreamSubscription<FoundDeviceEvent> _foundDeviceEventSub;
  late final StreamSubscription<DeviceCommunicationEvent> _deviceCommunicationSub;
  late final StreamSubscription<DeviceBoundEvent> _deviceBoundSub;
  late final StreamSubscription<DeviceRemovedEvent> _deviceRemovedSub;

  // locking / heartbeat state remains
  final Lock _hbLock = Lock();
  final Lock _observationLock = Lock();
  final Map<String, int> _consecutiveFailures = {};
  final Map<String, StreamSubscription> _observationSubscriptions = {};
  final Map<String, int> _missedObservations = {};
  final Map<String, Timer> _observationTimeoutTimers = {};
  // Default values
  static const int _defaultMaxMissedObservations = 3;
  static const int _defaultConsecutiveFailureThreshold = 2;
  static const int _defaultHeartbeatRetryMaxAttempts = 1;
  static const int _defaultObservationTimeoutMultiplier = 2;

  @override
  bool get isInitialized => _isInitialized;

  @override
  GlobalDevicesEventBus get events => _events;

  @override
  Iterable<Driver> get activatedDrivers => _bindingEngine.boundDevices.map((b) => b.driver);

  @override
  Iterable<BoundDevice> get boundDevices => _bindingEngine.boundDevices;

  @override
  bool get isBusy => _bindingEngine.isBusy;

  @override
  bool get isScanning => _isScanning || _discoveryManager.isActive;

  DefaultKernel(
    this._logger,
    this._driverRegistry, {
    this.mdnsProvider,
    DiscoveryManager? discoveryManager,
    BindingEngine? bindingEngine,
    // allow overriding heartbeat/probe parameters for faster detection
    Duration? localProbeTimeout,
    Duration? localBindTimeout,
    Duration? heartbeatPollingInterval,
    int? maxMissedObservations,
    int? consecutiveFailureThreshold,
    int? heartbeatRetryMaxAttempts,
    int? observationTimeoutMultiplier,
  }) : localProbeTimeout = localProbeTimeout ?? const Duration(seconds: 1),
       localBindTimeout = localBindTimeout ?? const Duration(seconds: 5),
       heartbeatPollingInterval = heartbeatPollingInterval ?? const Duration(seconds: 5),
       maxMissedObservations = maxMissedObservations ?? _defaultMaxMissedObservations,
       consecutiveFailureThreshold = consecutiveFailureThreshold ?? _defaultConsecutiveFailureThreshold,
       heartbeatRetryMaxAttempts = heartbeatRetryMaxAttempts ?? _defaultHeartbeatRetryMaxAttempts,
       observationTimeoutMultiplier = observationTimeoutMultiplier ?? _defaultObservationTimeoutMultiplier {
    // initialize late discovery manager after events are available
    _discoveryManager =
        discoveryManager ?? DefaultDiscoveryManager(_logger, _driverRegistry, _events, mdnsProvider: mdnsProvider);

    // binding engine initialization
    _bindingEngine =
        bindingEngine ?? DefaultBindingEngine(_logger, _driverRegistry, _events, localBindTimeout: localBindTimeout);

    _logger.i('Loading the kernel...');

    _deviceOfflineSub = _events.on<DeviceOfflineEvent>().listen((event) async {
      try {
        await unbind(event.device.id);
      } catch (e, stackTrace) {
        _logger.e('Failed to unbind offline device ${event.device.id}: $e', error: e, stackTrace: stackTrace);
      }
    });

    _deviceCommunicationSub = _events.on<DeviceCommunicationEvent>().listen((event) {
      _onDeviceCommunication(event.device.id);
    });

    _foundDeviceEventSub = _events.on<FoundDeviceEvent>().listen(_onDeviceFound);

    // hook engine events so kernel can start/stop heartbeat
    _deviceBoundSub = _events.on<DeviceBoundEvent>().listen((e) {
      final bound = _bindingEngine.getBoundDevice(e.device.id);
      if (bound == null) return;
      final drvDesc = _driverRegistry.metaDrivers[bound.driverID];
      if (drvDesc?.heartbeatMethod == HeartbeatMethod.push) {
        _startHeartbeatObservation(bound.device, bound.driver);
      }
      if (!_pollIDList.contains(bound.device.id) && drvDesc?.heartbeatMethod == HeartbeatMethod.poll) {
        _pollIDList.add(bound.device.id);
      }
    });
    _deviceRemovedSub = _events.on<DeviceRemovedEvent>().listen((e) => _stopHeartbeatObservation(e.device.id));

    // forward discovery manager lost events to kernel event bus
    _discoveryManager.onDeviceLost.listen((id) {
      _events.fire(UnboundDeviceLostEvent(id));
    });
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
        // let discovery manager cleanup if necessary
        _discoveryManager.stop();
      }

      _masterCancelToken.cancel();
      _timer?.cancel();
      _heartbeatPollingTaskCancelToken.cancel();

      _deviceOfflineSub.cancel();
      _foundDeviceEventSub.cancel();
      _deviceCommunicationSub.cancel();

      for (final subscription in _observationSubscriptions.values) {
        subscription.cancel();
      }
      _observationSubscriptions.clear();

      for (final timer in _observationTimeoutTimers.values) {
        timer.cancel();
      }
      _observationTimeoutTimers.clear();

      // binding engine manages its own subscriptions and drivers
      _bindingEngine.dispose();

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
    final bound = _bindingEngine.getBoundDevice(deviceID);
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
    return _bindingEngine.getBoundDevice(deviceID) != null;
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
    return _bindingEngine.tryBind(device, driverID, cancelToken: cancelToken);
  }

  @override
  Future<void> bind(Device device, String driverID, {CancellationToken? cancelToken}) async {
    cancelToken?.throwIfCancelled();
    _ensureStarted();
    assert(_registeredDevices.containsKey(device.id));

    await _bindingEngine.bind(device, driverID, cancelToken: cancelToken);
  }

  @override
  Future<void> unbind(String deviceID, {CancellationToken? cancelToken}) async {
    _ensureStarted();
    assert(_registeredDevices.containsKey(deviceID));
    await _bindingEngine.unbind(deviceID, cancelToken: cancelToken);
  }

  @override
  Future<void> unbindAll({CancellationToken? cancelToken}) async {
    _ensureStarted();
    await _bindingEngine.unbindAll(cancelToken: cancelToken);
  }

  void _startTimer() {
    assert(!_isDisposed);

    _timer ??= Timer.periodic(heartbeatPollingInterval, (_) {
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
        maxAttempts: heartbeatRetryMaxAttempts,
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

  Future<void> _startHeartbeatObservation(Device device, Driver driver) async {
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
          final errStr = error.toString();
          final isTransient = errStr.contains('CoapRequestException') || errStr.contains('timed out');
          if (isTransient) {
            _logger.w('Heartbeat observation transient error for device $deviceId: $error');
            _onHeartbeatMissed(deviceId); // count as a single missed heartbeat
          } else {
            _logger.e('Heartbeat observation unexpected error for device $deviceId: $error');
            // For unexpected errors we still treat it as a single miss (not double)
            _onHeartbeatMissed(deviceId);
          }
        },
        onDone: () {
          _logger.w('Heartbeat observation ended for device $deviceId');
          _onHeartbeatMissed(deviceId);
        },
        cancelOnError: false,
      );

      // Reset missed observations counter (within observation lock)
      await _observationLock.synchronized(() {
        _missedObservations[deviceId] = 0;
        // Set up timeout timer
        _resetObservationTimeout(deviceId);
      });
    } catch (e, stackTrace) {
      _logger.e('Failed to start heartbeat observation for device ${device.id}', error: e, stackTrace: stackTrace);
    }
  }

  void _onHeartbeatReceived(String deviceId, dynamic timestamp) {
    _observationLock.synchronized(() {
      _logger.d('Heartbeat received for device $deviceId: $timestamp');

      // Reset missed observations counter
      _missedObservations[deviceId] = 0;

      // Reset timeout timer
      _resetObservationTimeout(deviceId);
    });
  }

  void _onDeviceCommunication(String deviceId) {
    _observationLock.synchronized(() {
      if (_missedObservations.containsKey(deviceId)) {
        // Reset missed observations counter
        _missedObservations[deviceId] = 0;
        // Reset timeout timer
        _resetObservationTimeout(deviceId);
      }
    });
  }

  void _onHeartbeatMissed(String deviceId) {
    _observationLock.synchronized(() {
      _missedObservations[deviceId] = (_missedObservations[deviceId] ?? 0) + 1;
      _logger.w('Heartbeat missed for device $deviceId. Total missed: ${_missedObservations[deviceId]}');

      if (_missedObservations[deviceId]! >= maxMissedObservations) {
        _logger.w('Device $deviceId marked offline after $maxMissedObservations missed observations');

        // Find the device and mark it offline
        final boundDevice = _bindingEngine.getBoundDevice(deviceId);
        if (boundDevice != null) {
          _events.fire(DeviceOfflineEvent(boundDevice.device));
        }

        // Clean up observation
        _stopHeartbeatObservation(deviceId);
      } else {
        // Reset timeout timer for next observation
        _resetObservationTimeout(deviceId);
      }
    });
  }

  void _resetObservationTimeout(String deviceId) {
    // Note: This method is called within _observationLock.synchronized()
    _observationTimeoutTimers[deviceId]?.cancel();

    // Set timeout for a multiple of the normal heartbeat interval
    _observationTimeoutTimers[deviceId] = Timer(
      heartbeatPollingInterval * observationTimeoutMultiplier,
      () => _onHeartbeatMissed(deviceId),
    );
  }

  Future<void> _stopHeartbeatObservation(String deviceId) async {
    await _observationLock.synchronized(() async {
      _observationSubscriptions[deviceId]?.cancel();
      _observationSubscriptions.remove(deviceId);

      _observationTimeoutTimers[deviceId]?.cancel();
      _observationTimeoutTimers.remove(deviceId);

      _missedObservations.remove(deviceId);
    });
  }

  Future<void> _heartbeatPollingPeriodicTask({CancellationToken? cancelToken}) async {
    if (_heartbeatSuspended) {
      _logger.t('Heartbeat polling skipped because suspended.');
      return;
    }

    if (!isInitialized) {
      return;
    }

    if (isBusy) {
      _logger.t('Heartbeat polling skipped due to kernel is busy.');
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
              for (final bd in _bindingEngine.boundDevices) {
                final driverDesc = _driverRegistry.metaDrivers[bd.driverID];
                if (driverDesc?.heartbeatMethod != HeartbeatMethod.poll) {
                  continue;
                }

                if (bd.device.driverData.isBusy) {
                  _logger.t('Skip heartbeat for ${bd.device.id} because driver lock is busy.');
                  continue;
                }

                final queue = bd.device.driverData.queue;
                // Prefer user-initiated operations; skip polling when device IO queue is active.
                if (!queue.isIdle) {
                  _logger.t('Skip heartbeat for ${bd.device.id} because IO queue is busy.');
                  continue;
                }

                futures.add(
                  _tryDoHeartBeat(
                    bd,
                    localProbeTimeout,
                  ).catchError((_) => false).asCancellable(_heartbeatPollingTaskCancelToken),
                );
                devices.add(bd);
              }

              _logger.d('Polling heartbeat for (${devices.length}) bound devices...');
              final results = await Future.wait(futures).asCancellable(_heartbeatPollingTaskCancelToken);
              for (int i = 0; i < results.length; i++) {
                final deviceId = devices[i].device.id;
                if (!results[i]) {
                  _consecutiveFailures[deviceId] = (_consecutiveFailures[deviceId] ?? 0) + 1;
                  _logger.w(
                    'The device(${devices[i].device}) is not responding. Consecutive failures: ${_consecutiveFailures[deviceId]}',
                  );

                  // Only mark as offline after configured consecutive failures
                  if (_consecutiveFailures[deviceId]! >= consecutiveFailureThreshold) {
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

  @override
  void suspendHeartbeat() {
    _heartbeatSuspended = true;
  }

  @override
  void resumeHeartbeat() {
    _heartbeatSuspended = false;
  }

  void _onDeviceFound(FoundDeviceEvent event) {
    _ensureStarted();
    _logger.d(
      'Found mDNS service: , name=`${event.discovered.name}`, host=`${event.discovered.host}`, port=`${event.discovered.port}`',
    );
    final matched = _matchesDriver(event.discovered);
    if (matched != null) {
      final alreadyBound = _bindingEngine.boundDevices.any((x) => x.device.fingerprint == matched.fingerprint);
      if (!alreadyBound) {
        _logger.i('Unbound device found: `${matched.address}`');
        _events.fire(UnboundDeviceDiscoveredEvent(matched));
      }
    }
  }

  @override
  Future<void> startDevicesScanning({Duration? timeout, CancellationToken? cancelToken}) async {
    assert(!_isScanning);
    _isScanning = true;
    await _discoveryManager.start(timeout: timeout);
    _events.fire(DeviceDiscoveringStartedEvent());

    if (timeout != null) {
      Future.delayed(timeout, stopDevicesScanning).asCancellable(cancelToken);
    }
  }

  @override
  Future<void> stopDevicesScanning({CancellationToken? cancelToken}) async {
    assert(_isScanning);
    try {
      await _discoveryManager.stop();
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
