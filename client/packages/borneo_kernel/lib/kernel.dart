import 'dart:async';

import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'discovery_manager_impl.dart';
import 'binding_engine_impl.dart';
import 'heartbeat_service_impl.dart';

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

  bool _isInitialized = false;
  bool _isDisposed = false;
  bool _isScanning = false;

  late final HeartbeatService _heartbeatService;

  final Logger _logger;
  final IDriverRegistry _driverRegistry;
  final IMdnsProvider? mdnsProvider;
  late final DiscoveryManager _discoveryManager;
  late final BindingEngine _bindingEngine;

  final Map<String, BoundDeviceDescriptor> _registeredDevices = {};
  final GlobalDevicesEventBus _events = GlobalDevicesEventBus();
  final CancellationToken _masterCancelToken = CancellationToken();
  late final StreamSubscription<DeviceOfflineEvent> _deviceOfflineSub;
  late final StreamSubscription<FoundDeviceEvent> _foundDeviceEventSub;
  late final StreamSubscription<DeviceCommunicationEvent> _deviceCommunicationSub;
  late final StreamSubscription<DeviceBoundEvent> _deviceBoundSub;
  late final StreamSubscription<DeviceRemovedEvent> _deviceRemovedSub;

  // backoff state for retrying unbound devices
  final Map<String, int> _backoffCount = {};
  final Map<String, DateTime> _nextBindAttempt = {};
  static const Duration _maxBackoff = Duration(minutes: 1);

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
    HeartbeatService? heartbeatService,
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

    // construct heartbeat service (allow injection for tests)
    _heartbeatService =
        heartbeatService ??
        DefaultHeartbeatService(
          _logger,
          localProbeTimeout: this.localProbeTimeout,
          heartbeatPollingInterval: this.heartbeatPollingInterval,
          maxMissedObservations: this.maxMissedObservations,
          consecutiveFailureThreshold: this.consecutiveFailureThreshold,
          heartbeatRetryMaxAttempts: this.heartbeatRetryMaxAttempts,
          observationTimeoutMultiplier: this.observationTimeoutMultiplier,
        );

    _heartbeatService.onFailure.listen((device) {
      _events.fire(DeviceOfflineEvent(device));
    });

    _deviceOfflineSub = _events.on<DeviceOfflineEvent>().listen((event) async {
      try {
        await unbind(event.device.id);
      } catch (e, stackTrace) {
        _logger.e('Failed to unbind offline device ${event.device.id}: $e', error: e, stackTrace: stackTrace);
      }
    });

    _deviceCommunicationSub = _events.on<DeviceCommunicationEvent>().listen((event) {
      _heartbeatService.onDeviceCommunication(event.device.id);
    });

    _foundDeviceEventSub = _events.on<FoundDeviceEvent>().listen(_onDeviceFound);

    // hook engine events so kernel can start/stop heartbeat
    _deviceBoundSub = _events.on<DeviceBoundEvent>().listen((e) {
      final bound = _bindingEngine.getBoundDevice(e.device.id);
      if (bound == null) return;
      final drvDesc = _driverRegistry.metaDrivers[bound.driverID];
      final method = drvDesc?.heartbeatMethod ?? HeartbeatMethod.poll;
      _heartbeatService.registerDevice(bound, method);
    });
    _deviceRemovedSub = _events.on<DeviceRemovedEvent>().listen((e) => _heartbeatService.unregisterDevice(e.device.id));

    // subscribe to heartbeat ticks so we can probe unbound devices
    // backoff counters for unbound devices (stored as fields)

    _heartbeatService.onTick.listen((_) async {
      if (!_isInitialized || _isDisposed) return;
      if (isBusy) return; // let binding engine deal with concurrency

      final now = DateTime.now();
      const baseInterval = Duration(seconds: 1);

      // try to bind any registered but currently unbound devices
      for (final descriptor in _registeredDevices.values.where((d) => !isBound(d.device.id))) {
        final id = descriptor.device.id;
        final next = _nextBindAttempt[id] ?? DateTime.fromMillisecondsSinceEpoch(0);
        if (now.isBefore(next)) continue;

        bool success = false;
        try {
          success = await tryBind(descriptor.device, descriptor.driverID);
        } catch (_) {
          success = false;
        }

        if (success) {
          _backoffCount.remove(id);
          _nextBindAttempt.remove(id);
        } else {
          final count = (_backoffCount[id] ?? 0) + 1;
          _backoffCount[id] = count;
          // interval = min(base * 2^count, maxBackoff)
          final wait = baseInterval * (1 << (count - 1));
          _nextBindAttempt[id] = now.add(wait < _maxBackoff ? wait : _maxBackoff);
        }
      }
    });

    // forward discovery manager lost events to kernel event bus
    _discoveryManager.onDeviceLost.listen((id) {
      _events.fire(UnboundDeviceLostEvent(id));
    });
  }

  @override
  Future<void> start({CancellationToken? cancelToken}) async {
    _logger.i('Starting the device management kernel...');

    await _heartbeatService.start();
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
      _heartbeatService.stop();

      _deviceOfflineSub.cancel();
      _foundDeviceEventSub.cancel();
      _deviceCommunicationSub.cancel();
      _deviceBoundSub.cancel();
      _deviceRemovedSub.cancel();

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

  // heartbeat timer logic moved into HeartbeatService

  // polling helper moved into HeartbeatService

  // observation logic moved into HeartbeatService

  // moved to HeartbeatService

  // communication handling moved to HeartbeatService

  // observation failure handled by HeartbeatService

  // helper moved to HeartbeatService

  // helper moved to HeartbeatService

  // full heartbeat polling and observation logic moved into service

  void _ensureStarted() {
    if (_isInitialized == false) {
      throw InvalidOperationException(message: 'The kernel has not been initialized!');
    }
    assert(!_isDisposed);
  }

  @override
  void suspendHeartbeat() {
    _heartbeatService.suspend();
  }

  @override
  void resumeHeartbeat() {
    _heartbeatService.resume();
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
