import 'dart:async';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/features/devices/models/discoverable_device.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';

import '../models/events.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';

class DeviceDiscoveryViewModel extends AbstractScreenViewModel {
  bool _disposed = false;
  final Logger _logger;
  final IGroupManager _groupManager;
  final IDeviceManager _deviceManager;
  final IDeviceModuleRegistry deviceMdoules;

  bool get _isDiscovering => _deviceManager.isDiscoverying;
  bool _isBleScanning = false;

  late final StreamSubscription<NewDeviceEntityAddedEvent> _deviceAddedEventSub;
  late final StreamSubscription<NewDeviceFoundEvent> _newDeviceFoundEventSub;

  // Internal lists
  List<String> _unprovisioned = [];
  final List<SupportedDeviceDescriptor> _provisioned = [];

  // Exposed list
  final ValueNotifier<List<DiscoverableDevice>> _discoverableDevices = ValueNotifier([]);
  ValueNotifier<List<DiscoverableDevice>> get discoverableDevices => _discoverableDevices;

  DeviceEntity? _lastestAddedDevice;
  DeviceEntity? get lastestAddedDevice => _lastestAddedDevice;

  late final List<DeviceGroupEntity> _availableGroups = [];
  List<DeviceGroupEntity> get availableGroups => _availableGroups;

  bool get isDiscovering => _isBleScanning;

  // Platform check
  bool get isMobile => defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS;

  DeviceDiscoveryViewModel(
    this._logger,
    this._groupManager,
    this._deviceManager,
    this.deviceMdoules, {
    required super.globalEventBus,
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
      await startDiscovery();
    } finally {}
  }

  @override
  void dispose() {
    if (!_disposed) {
      _deviceAddedEventSub.cancel();
      _newDeviceFoundEventSub.cancel();
      _discoverableDevices.dispose();
      if (_isDiscovering || _isBleScanning) {
        stopDiscovery();
      }
      super.dispose();
      _disposed = true;
    }
  }

  Future<void> stopDiscovery() async {
    _isBleScanning = false;
    notifyListeners();

    try {
      if (_isDiscovering) {
        await _deviceManager.stopDiscovery();
      }
    } catch (e, stackTrace) {
      super.notifyAppError('Error occurred while stopping discovery: $e', error: e, stackTrace: stackTrace);
    } finally {
      notifyListeners();
    }
  }

  // Clean resources when leaving screen or stopping
  Future<bool> onWillPop() async {
    await stopDiscovery();
    return true;
  }

  Future<void> startDiscovery() async {
    if (isDiscovering) return; // Already running

    // Clear previous results
    _unprovisioned.clear();
    _provisioned.clear();
    _updateDiscoverableList();

    try {
      _isBleScanning = true;
      notifyListeners(); // Update UI to show loading

      // Stop any existing discovery first
      await stopDiscovery();

      // Start mDNS discovery (platform independent)
      try {
        await _deviceManager.startDiscovery();
      } catch (e) {
        _logger.e('Failed to start mDNS discovery', error: e);
      }

      // Start BLE discovery (Mobile only)
      if (isMobile) {
        await _startBleScan();
      } else {
        _isBleScanning = false;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      super.notifyAppError('Error occurred while discovering devices: $e', error: e, stackTrace: stackTrace);
      _logger.e('Failed to discovering devices', error: e, stackTrace: stackTrace);
      _isBleScanning = false;
      notifyListeners();
    }
  }

  Future<void> _startBleScan() async {
    try {
      // Check permissions
      Map<Permission, PermissionStatus> statuses = await [
        Permission.locationWhenInUse,
        Permission.bluetoothScan,
        Permission.bluetoothConnect,
      ].request();

      bool permissionsGranted = true;
      // You can add stricter checks here if needed.

      // Perform scan
      final devices = await _deviceManager.bleProvisioner.scanBleDevices('BOPROV_');
      _unprovisioned = devices;
      _updateDiscoverableList();
    } catch (e) {
      _logger.e('BLE Scan failed', error: e);
    } finally {
      _isBleScanning = false;
      notifyListeners();
    }
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
