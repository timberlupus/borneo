import 'dart:async';
import 'package:flutter/services.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/discoverable_device.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:borneo_app/core/services/platform_service.dart';

import '../models/events.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/devices/ble_provisioner.dart';

const int kDiscoveryTimeoutSeconds = 10;

/// When automatic post‑provisioning mode is enabled we keep the mDNS listener
/// active for this many seconds in order to pick up the newly‑added device.
/// 30 s should be plenty in almost all environments.
const int kAutoAddTimeoutSeconds = 30;

class DeviceDiscoveryViewModel extends AbstractScreenViewModel {
  bool _disposed = false;
  late CancellationToken _scanCancelToken = CancellationToken();
  Timer? _countdownTimer;
  int _remainingSeconds = kDiscoveryTimeoutSeconds;
  final Logger _logger;
  final IDeviceManager _deviceManager;
  final IBleProvisioner _bleProvisioner;
  final IDeviceModuleRegistry deviceMdoules;
  final PlatformService _platformService;

  // cache BLE name -> resolved device name as obtained via fetchDeviceInfo
  final Map<String, String> _resolvedDeviceNames = {};

  // when true we will automatically add any provisioned device we see
  // via mDNS (used after provisioning completes).
  bool _autoAddWhenFound = false;
  Timer? _autoAddTimer;

  bool get _isDiscovering => _deviceManager.isDiscoverying;
  bool _isRefreshing = false;

  late final StreamSubscription<NewDeviceEntityAddedEvent> _deviceAddedEventSub;
  late final StreamSubscription<NewDeviceFoundEvent> _newDeviceFoundEventSub;

  // Internal lists
  List<String> _unprovisioned = [];
  final List<SupportedDeviceDescriptor> _provisioned = [];

  // Exposed list
  final ValueNotifier<List<DiscoverableDevice>> _discoverableDevices = ValueNotifier([]);
  ValueNotifier<List<DiscoverableDevice>> get discoverableDevices => _discoverableDevices;

  final ValueNotifier<String?> _scanError = ValueNotifier(null);
  ValueNotifier<String?> get scanError => _scanError;

  DeviceEntity? _lastestAddedDevice;
  DeviceEntity? get lastestAddedDevice => _lastestAddedDevice;

  bool get isDiscovering => _isRefreshing;
  int get remainingSeconds => _remainingSeconds;

  // Platform check
  bool get isMobile => _platformService.isMobile;

  DeviceDiscoveryViewModel(
    this._logger,
    this._deviceManager,
    this._bleProvisioner,
    this.deviceMdoules,
    this._platformService, {
    required super.globalEventBus,
    required super.gt,
    super.logger,
    // helper for testing permission error handling
    this.requestBlePermissions,
  }) {
    _deviceAddedEventSub = _deviceManager.allDeviceEvents.on<NewDeviceEntityAddedEvent>().listen(
      (event) => _onNewDeviceEntityAdded(event),
    );

    _newDeviceFoundEventSub = _deviceManager.allDeviceEvents.on<NewDeviceFoundEvent>().listen(
      (event) => _onNewDeviceFound(event),
    );
  }

  @override
  Future<void> onInitialize() async {
    try {
      // 延迟到下一帧，确保 UI 完全初始化
      await Future.delayed(Duration.zero);
      await startDiscovery();
    } finally {}
  }

  @override
  void dispose() {
    if (!_disposed) {
      _countdownTimer?.cancel();
      _countdownTimer = null;
      _autoAddTimer?.cancel();
      _autoAddTimer = null;
      _deviceAddedEventSub.cancel();
      _newDeviceFoundEventSub.cancel();
      _discoverableDevices.dispose();
      _scanError.dispose();
      if (_isRefreshing || _isDiscovering) {
        _scanCancelToken.cancel();
      }
      super.dispose();
      _disposed = true;
    }
  }

  Future<void> _stopRefresh() async {
    _countdownTimer?.cancel();
    _countdownTimer = null;
    _remainingSeconds = kDiscoveryTimeoutSeconds;
    _isRefreshing = false;
    _scanCancelToken.cancel();

    // also cancel auto‑add mode
    _autoAddTimer?.cancel();
    _autoAddTimer = null;
    _autoAddWhenFound = false;

    try {
      if (_isDiscovering) {
        await _deviceManager.stopDiscovery();
      }
    } catch (e, stackTrace) {
      _logger.e('Error stopping discovery', error: e, stackTrace: stackTrace);
    } finally {
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  Future<void> stopDiscovery() async {
    await _stopRefresh();
  }

  // Clean resources when leaving screen or stopping
  Future<bool> onWillPop() async {
    await _stopRefresh();
    return true;
  }

  /// Begins discovery.  Normally this just runs the regular mDNS scan and
  /// optionally a BLE scan if running on mobile.  If [autoAdd] is true we
  /// additionally keep the mDNS listener active for [autoAddTimeoutSeconds]
  /// and add any newly‑found device to the ungrouped pool.
  Future<void> startDiscovery({bool autoAdd = false, int autoAddTimeoutSeconds = kAutoAddTimeoutSeconds}) async {
    if (_isRefreshing) return; // Already refreshing

    // cancel any previous auto‑add timer
    _autoAddTimer?.cancel();
    _autoAddWhenFound = autoAdd;
    if (autoAdd) {
      _autoAddTimer = Timer(Duration(seconds: autoAddTimeoutSeconds), () {
        _autoAddWhenFound = false;
        _autoAddTimer = null;
      });
    }

    // reset resolved name cache when starting a fresh scan
    _resolvedDeviceNames.clear();

    if (_isRefreshing) return; // Already refreshing

    // Create new cancellation token for this operation
    _scanCancelToken = CancellationToken();

    // Clear all results
    _unprovisioned.clear();
    _provisioned.clear();
    _scanError.value = null; // Clear previous error
    _updateDiscoverableList();

    _isRefreshing = true;
    _remainingSeconds = kDiscoveryTimeoutSeconds;
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_disposed) {
        timer.cancel();
        return;
      }
      _remainingSeconds--;
      if (_remainingSeconds <= 0) {
        timer.cancel();
        _countdownTimer = null;
        stopDiscovery();
      } else {
        notifyListeners();
      }
    });
    if (!_disposed) {
      notifyListeners(); // Update UI to show loading
    }

    try {
      // Stop any existing discovery first
      if (_isDiscovering) {
        await _deviceManager.stopDiscovery();
      }

      // Start mDNS discovery (runs continuously in background, don't await)
      _deviceManager.startDiscovery();

      // Start BLE discovery (Mobile only) - run in background
      if (isMobile) {
        unawaited(
          _startBleScan().catchError((error, stackTrace) {
            _logger.e('BLE scan error', error: error, stackTrace: stackTrace);
            if (!_disposed) {
              _scanError.value = gt.translate('Bluetooth scan error, please check if Bluetooth device is enabled.');
            }
          }),
        );
      }

      if (_scanCancelToken.isCancelled) {
        return;
      }
    } on CancelledException {
      _logger.i('Device discovery has been cancelled.');
    } catch (e, stackTrace) {
      if (_scanCancelToken.isCancelled) return;
      _logger.e('Discovery error', error: e, stackTrace: stackTrace);
      if (!_disposed) {
        _scanError.value = gt.translate('Bluetooth scan error, please check if Bluetooth device is enabled.');
      }
    }
  }

  /// Requests the set of permissions required for BLE discovery and
  /// returns `true` if all of them are granted. This method is deliberately
  /// public so that tests can supply a fake implementation.
  Future<bool> Function()? requestBlePermissions;

  @visibleForTesting
  List<Permission> blePermissionList() {
    // iOS only has a single Bluetooth permission; Android requires location +
    // separate scan/connect permissions.  The list is kept in a method so tests
    // can verify the behaviour without mocking the plugin itself.
    if (_platformService.isIOS) {
      return [
        Permission.bluetooth,
        // location may also be required when scanning on iOS
        Permission.locationWhenInUse,
      ];
    } else {
      return [Permission.locationWhenInUse, Permission.bluetoothScan, Permission.bluetoothConnect];
    }
  }

  Future<bool> _ensureBlePermissions() async {
    // allow injection for tests
    if (requestBlePermissions != null) {
      return await requestBlePermissions!();
    }

    final permissions = blePermissionList();
    final statuses = await permissions.request();
    _logger.d('BLE permission statuses: $statuses');

    // if any permission is not granted, treat as failure
    for (var status in statuses.values) {
      if (!status.isGranted) {
        return false;
      }
    }
    return true;
  }

  Future<void> _startBleScan() async {
    final granted = await _ensureBlePermissions();
    if (!granted) {
      if (!_disposed) {
        _scanError.value = gt.translate('Bluetooth permissions are required to discover devices.');
      }
      return;
    }

    try {
      final devices = await _bleProvisioner.scanBleDevices('BOPROV_', cancelToken: _scanCancelToken);
      // Instead of publishing raw names immediately, resolve each one and only
      // add to the unprovisioned list when we have a display name (or fall back
      // to the BLE name if resolution fails).  This avoids flicker in the UI.
      _unprovisioned.clear();
      for (var name in devices) {
        if (_scanCancelToken.isCancelled) break;
        try {
          final info = await _bleProvisioner.fetchDeviceInfo(deviceName: name, cancelToken: _scanCancelToken);
          // require successful info; if name blank treat as failure too
          if (info.name.isNotEmpty) {
            _resolvedDeviceNames[name] = info.name;
            _unprovisioned.add(name);
            _updateDiscoverableList();
          } else {
            _logger.w('Resolved info had empty name for $name, skipping');
          }
        } catch (e, st) {
          _logger.w('Failed to resolve name for $name - omitting', error: e, stackTrace: st);
          // skip device entirely
        }
      }
    } on CancelledException {
      _logger.i('BLE scan was cancelled by user.');
      return;
    } catch (e, stackTrace) {
      _logger.e('BLE provisioning scan failed', error: e, stackTrace: stackTrace);
      if (!_disposed) {
        if (e is PlatformException && e.code == 'PERMISSION_DENIED') {
          _scanError.value = gt.translate('Bluetooth permissions are required to discover devices.');
        } else {
          _scanError.value = gt.translate('Bluetooth scan error, please check if Bluetooth device is enabled.');
        }
      }
    }
  }

  /// Attempts to resolve a set of BLE names using [IBleProvisioner.fetchDeviceInfo].
  ///
  /// Each result is stored in [_resolvedDeviceNames] and triggers a UI refresh.
  Future<void> _resolveDeviceNames(List<String> names) async {
    for (var name in names) {
      if (_scanCancelToken.isCancelled) return;
      try {
        final info = await _bleProvisioner.fetchDeviceInfo(deviceName: name, cancelToken: _scanCancelToken);
        if (info.name.isNotEmpty) {
          _resolvedDeviceNames[name] = info.name;
          _updateDiscoverableList();
        }
      } catch (e, st) {
        _logger.w('Failed to resolve name for $name', error: e, stackTrace: st);
      }
    }
  }

  Future<void> addNewDevice(SupportedDeviceDescriptor deviceInfo) async {
    await _deviceManager.addNewDevice(deviceInfo, groupID: null);
  }

  Future<void> _onNewDeviceEntityAdded(NewDeviceEntityAddedEvent event) async {
    try {
      _provisioned.removeWhere((x) => x.fingerprint == event.device.fingerprint);
      _lastestAddedDevice = event.device;
      _updateDiscoverableList();
    } finally {
      notifyListeners();
    }
  }

  Future<void> _onNewDeviceFound(NewDeviceFoundEvent event) async {
    try {
      // Avoid duplicates
      if (!_provisioned.any((d) => d.fingerprint == event.device.fingerprint)) {
        _provisioned.add(event.device);
        if (_autoAddWhenFound) {
          try {
            await addNewDevice(event.device);
          } catch (e, st) {
            _logger.e('Auto‑add failed', error: e, stackTrace: st);
          }
        }
        _updateDiscoverableList();
      }
    } finally {
      notifyListeners();
    }
  }

  void _updateDiscoverableList() {
    List<DiscoverableDevice> list = [];

    // Provisioned first
    list.addAll(_provisioned.map((d) => DiscoverableDevice.provisioned(d)));

    // Unprovisioned second; include any resolved names we have cached
    list.addAll(
      _unprovisioned.map((name) => DiscoverableDevice.unprovisioned(name, resolvedName: _resolvedDeviceNames[name])),
    );

    _discoverableDevices.value = list;
  }

  void clearAddedDevice() {
    _lastestAddedDevice = null;
    notifyListeners();
  }
}
