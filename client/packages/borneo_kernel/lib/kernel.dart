import 'dart:async';

import 'package:borneo_kernel_abstractions/errors.dart';
import 'package:borneo_kernel_abstractions/models/heartbeat_method.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';
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
  final Map<String, StreamSubscription> _deviceEventRouters = {};
  final GlobalDevicesEventBus _events = GlobalDevicesEventBus();
  final Set<String> _pollIDList = {};
  final CancellationToken _heartbeatPollingTaskCancelToken = CancellationToken();
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
      _isDisposed = true; // 首先标记为已销毁，避免其他操作

      // 停止扫描（在销毁EventBus之前）
      if (isScanning) {
        // 直接设置扫描状态为false，避免异步操作
        _isScanning = false;
        // 同步停止mDNS发现
        if (mdnsProvider != null) {
          for (final disc in _mdnsDiscoveryList) {
            disc.dispose();
          }
          _mdnsDiscoveryList.clear();
        }
      }

      // 取消令牌和定时器
      _masterCancelToken.cancel();
      _timer?.cancel();
      _heartbeatPollingTaskCancelToken.cancel();

      // 取消事件订阅
      _deviceOfflineSub.cancel();
      _foundDeviceEventSub.cancel();

      // 清理所有绑定的设备
      for (final deviceEventRouter in _deviceEventRouters.values) {
        deviceEventRouter.cancel();
      }
      _deviceEventRouters.clear();

      for (final boundDevice in _boundDevices.values) {
        boundDevice.dispose();
      }
      _boundDevices.clear();

      // 清理所有激活的驱动程序
      for (final driver in _activatedDrivers.values) {
        driver.dispose();
      }
      _activatedDrivers.clear();

      // 最后销毁EventBus
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
  Future<bool> tryBind(Device device, String driverID, {Duration? timeout, CancellationToken? cancelToken}) async {
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
      events.fire(LoadingDriverFailedEvent(device, error: e, message: e.toString()));
      return false;
    }
  }

  @override
  Future<void> bind(Device device, String driverID, {Duration? timeout, CancellationToken? cancelToken}) async {
    // 在获取锁之前检查取消状态
    cancelToken?.throwIfCancelled();

    await _deviceOpLock.synchronized(() async {
      _ensureStarted();

      // 在锁内再次检查取消状态
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

      final driverInitialized = await driver
          .probe(device, cancelToken: cancelToken)
          .timeout(timeout ?? kLocalProbeTimeOut);

      if (driverInitialized) {
        // Try to activate device
        final bound = BoundDevice(driverID, device, driver);
        _deviceEventRouters[device.id] = bound.device.driverData.deviceEvents.on().listen((event) {
          _events.fire(event);
        });

        _boundDevices[device.id] = bound;

        if (!_pollIDList.contains(device.id) && driverDesc.heartbeatMethod == HeartbeatMethod.poll) {
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
        await boundDevice.driver.remove(boundDevice.device, cancelToken: cancelToken);
        boundDevice.dispose();
        _boundDevices.remove(deviceID);

        _deviceEventRouters[deviceID]?.cancel();
        _deviceEventRouters.remove(deviceID);

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

  Future<void> _heartbeatPollingPeriodicTask({CancellationToken? cancelToken}) async {
    if (!isInitialized) {
      return;
    }
    if (_deviceOpLock.locked) {
      _logger.t('Heartbeat polling skipped due to device operation lock.');
      return;
    }

    // 收集需要离线处理的设备
    final List<Device> offlineDevices = [];

    try {
      await _deviceOpLock
          .synchronized(() async {
            final futures = <Future<bool>>[];

            // BoundDevices
            {
              final devices = <BoundDevice>[];
              for (final bd in _boundDevices.values) {
                if (_pollIDList.contains(bd.device.id)) {
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
                if (!results[i]) {
                  _logger.w('The device(${devices[i].device}) is not responding.');
                  // 收集离线设备，稍后在锁外处理
                  offlineDevices.add(devices[i].device);
                }
              }
            }

            // UnboundDevices
            futures.clear();
            final unboundDeviceDescriptors = _registeredDevices.values.where((x) => !isBound(x.device.id)).toList();
            for (final descriptor in unboundDeviceDescriptors) {
              futures.add(
                tryBind(
                  descriptor.device,
                  descriptor.driverID,
                  timeout: kLocalProbeTimeOut,
                  cancelToken: _heartbeatPollingTaskCancelToken,
                ),
              );
            }
            _logger.d('Polling heartbeat for (${unboundDeviceDescriptors.length}) unbound devices...');
            final boundResults = await Future.wait(
              futures,
            ).timeout(kHeartbeatPollingInterval).asCancellable(_heartbeatPollingTaskCancelToken);
            for (int i = 0; i < boundResults.length; i++) {
              /*
      if (!boundResults[i]) {
        _logger
              .w('Failed to bind device()');
      }
            */
            }
          }, timeout: kHeartbeatPollingInterval)
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
      // 只在未销毁时发送事件
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
