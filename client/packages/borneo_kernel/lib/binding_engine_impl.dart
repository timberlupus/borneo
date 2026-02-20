import 'dart:async';

import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:synchronized/synchronized.dart';

import 'package:borneo_kernel_abstractions/kernel.dart';

/// Default implementation of [BindingEngine].  This class owns all driver
/// activation/purge logic and maintains the maps of bound devices used by the
/// kernel in the original monolithic implementation.  It fires the same
/// events the kernel previously fired so that callers (for example the
/// heartbeat subsystem) continue to work unchanged.
class DefaultBindingEngine implements BindingEngine {
  final Logger _logger;
  final IDriverRegistry _driverRegistry;
  final EventDispatcher _events;

  // Configurable timeouts carried over from the kernel constructor.
  final Duration localBindTimeout;

  DefaultBindingEngine(this._logger, this._driverRegistry, this._events, {Duration? localBindTimeout})
    : localBindTimeout = localBindTimeout ?? const Duration(seconds: 5);

  final Map<String, BoundDevice> _boundDevices = {};
  final Map<String, Driver> _activatedDrivers = {};
  final Map<String, StreamSubscription> _deviceEventRouters = {};
  final Map<String, Lock> _deviceBindLocks = {};

  final Lock _boundDevicesLock = Lock();

  @override
  bool get isBusy => _deviceBindLocks.values.any((lock) => lock.inLock);

  @override
  Iterable<BoundDevice> get boundDevices => _boundDevices.values;

  @override
  BoundDevice? getBoundDevice(String deviceID) => _boundDevices[deviceID];

  Driver _ensureDriverActivated(String driverID) {
    return _activatedDrivers.putIfAbsent(driverID, () {
      final desc = _driverRegistry.metaDrivers[driverID];
      if (desc == null) {
        throw ArgumentError('Unknown driverID $driverID');
      }
      final drv = desc.factory(logger: _logger);
      return drv;
    });
  }

  void _purgeUnusedDriver() {
    final toRemove = <String>[];
    for (final entry in _activatedDrivers.entries) {
      final inUse = _boundDevices.values.any((b) => b.driverID == entry.key);
      if (!inUse) {
        toRemove.add(entry.key);
      }
    }
    for (final id in toRemove) {
      final drv = _activatedDrivers.remove(id)!;
      drv.dispose();
    }
  }

  @override
  Future<bool> tryBind(Device device, String driverID, {CancellationToken? cancelToken}) async {
    if (getBoundDevice(device.id) != null) {
      return true;
    }
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
      _logger.e('Engine error: $e', error: e, stackTrace: stackTrace);
      _events.fire(LoadingDriverFailedEvent(device, error: e, message: e.toString()));
      return false;
    }
  }

  @override
  Future<void> bind(Device device, String driverID, {CancellationToken? cancelToken}) async {
    cancelToken?.throwIfCancelled();

    final deviceLock = _boundDevicesLock.synchronized(() {
      return _deviceBindLocks.putIfAbsent(device.id, () => Lock());
    });

    final eventsToFire = [];

    await deviceLock.then(
      (lock) => lock.synchronized(() async {
        cancelToken?.throwIfCancelled();

        _logger.i('Binding device: `$device` to driver `$driverID`');

        var driverDesc = _driverRegistry.metaDrivers[driverID];
        if (driverDesc == null) {
          final msg = 'Failed to find the driver key `$driverID` for device(`${device.address}`)';
          _logger.e(msg);
          throw ArgumentError(msg, 'device');
        }
        final driver = _ensureDriverActivated(driverID);

        final driverInitialized = await driver.probe(device, cancelToken: cancelToken);

        if (driverInitialized) {
          final bound = BoundDevice(driverID, device, driver);

          await _boundDevicesLock.synchronized(() async {
            _deviceEventRouters[device.id] = bound.device.driverData.deviceEvents.on().listen((event) {
              _events.fire(event);
            });

            eventsToFire.add(DeviceBoundEvent(device));

            _boundDevices[device.id] = bound;
          });
        } else {
          throw DeviceProbeError("Failed to probe $device", device);
        }
      }, timeout: localBindTimeout),
    );

    for (final e in eventsToFire) {
      _events.fire(e);
    }
  }

  @override
  Future<void> unbind(String deviceID, {CancellationToken? cancelToken}) async {
    final deviceLock = await _boundDevicesLock.synchronized(() {
      return _deviceBindLocks[deviceID];
    });

    if (deviceLock != null) {
      await deviceLock.synchronized(() async {
        final boundDevice = _boundDevices[deviceID];
        if (boundDevice != null) {
          await boundDevice.driver.remove(boundDevice.device, cancelToken: cancelToken);
          boundDevice.dispose();

          await _boundDevicesLock.synchronized(() async {
            _boundDevices.remove(deviceID);
            _deviceEventRouters[deviceID]?.cancel();
            _deviceEventRouters.remove(deviceID);
          });

          _purgeUnusedDriver();

          _events.fire(DeviceRemovedEvent(boundDevice.device));
        }
      });
    }
  }

  @override
  Future<void> unbindAll({CancellationToken? cancelToken}) async {
    // iterate over snapshot to avoid concurrent modification
    final ids = List<String>.from(_boundDevices.keys);
    for (final id in ids) {
      await unbind(id, cancelToken: cancelToken);
    }
  }

  @override
  void dispose() {
    for (final sub in _deviceEventRouters.values) {
      sub.cancel();
    }
    _deviceEventRouters.clear();

    for (final drv in _activatedDrivers.values) {
      drv.dispose();
    }
    _activatedDrivers.clear();
    _boundDevices.clear();
    _deviceBindLocks.clear();
  }
}
