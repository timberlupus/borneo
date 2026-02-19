import 'dart:async';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/features/devices/models/discoverable_device.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/events.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/devices/ble_provisioner.dart';

class DeviceDiscoveryViewModel extends AbstractScreenViewModel {
  bool _disposed = false;
  late CancellationToken _scanCancelToken = CancellationToken();
  final Logger _logger;
  final IGroupManager _groupManager;
  final IDeviceManager _deviceManager;
  final IBleProvisioner _bleProvisioner;
  final IDeviceModuleRegistry deviceMdoules;

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

  late final List<DeviceGroupEntity> _availableGroups = [];
  List<DeviceGroupEntity> get availableGroups => _availableGroups;

  bool get isDiscovering => _isRefreshing;

  // Platform check
  bool get isMobile => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  DeviceDiscoveryViewModel(
    this._logger,
    this._groupManager,
    this._deviceManager,
    this._bleProvisioner,
    this.deviceMdoules, {
    required super.globalEventBus,
    required super.gt,
    super.logger,
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
      _availableGroups.addAll(await _groupManager.fetchAllGroupsInCurrentScene());
      // 延迟到下一帧，确保 UI 完全初始化
      await Future.delayed(Duration.zero);
      await startDiscovery();
    } finally {}
  }

  @override
  void dispose() {
    if (!_disposed) {
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
    _isRefreshing = false;
    _scanCancelToken.cancel();
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

  Future<void> startDiscovery() async {
    if (_isRefreshing) return; // Already refreshing

    // Create new cancellation token for this operation
    _scanCancelToken = CancellationToken();

    // Clear all results
    _unprovisioned.clear();
    _provisioned.clear();
    _scanError.value = null; // Clear previous error
    _updateDiscoverableList();

    _isRefreshing = true;
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

  Future<void> _startBleScan() async {
    // Check permissions
    await [Permission.locationWhenInUse, Permission.bluetoothScan, Permission.bluetoothConnect].request();

    // Perform scan
    final devices = await _bleProvisioner.scanBleDevices('BOPROV_', cancelToken: _scanCancelToken);
    _unprovisioned = devices;
    _updateDiscoverableList();
  }

  Future<void> addNewDevice(SupportedDeviceDescriptor deviceInfo, DeviceGroupEntity? group) async {
    await _deviceManager.addNewDevice(deviceInfo, groupID: group?.id);
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

    // Unprovisioned second
    list.addAll(_unprovisioned.map((name) => DiscoverableDevice.unprovisioned(name)));

    _discoverableDevices.value = list;
  }

  void clearAddedDevice() {
    _lastestAddedDevice = null;
    notifyListeners();
  }
}
