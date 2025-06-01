import 'dart:async';

import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/models/devices/device_group_entity.dart';
import 'package:borneo_app/services/group_manager.dart';
import 'package:borneo_app/view_models/abstract_screen_view_model.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:flutter/material.dart';
import 'package:logger/logger.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:esp_smartconfig/esp_smartconfig.dart';

import '../../models/devices/events.dart';
import '/view_models/base_view_model.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_app/services/device_manager.dart';

class DeviceDiscoveryViewModel extends AbstractScreenViewModel with ViewModelEventBusMixin {
  // TODO move this to device manager
  final Logger _logger;
  final _provisioner = Provisioner.espTouch();
  final GroupManager _groupManager;
  final DeviceManager _deviceManager;
  bool get _isDiscovering => _deviceManager.isDiscoverying;

  late final StreamSubscription<NewDeviceEntityAddedEvent> _deviceAddedEventSub;
  late final StreamSubscription<NewDeviceFoundEvent> _newDeviceFoundEventSub;

  String _ssid = '';
  String? _bssid;
  String _password = '';
  bool _isSmartConfigEnabled = false;
  bool _isFormValid = false;
  int _newDeviceCount = 0;
  int _discoveredCount = 0;

  // Getter for loading state
  bool get isDiscovering => _isDiscovering;

  final ValueNotifier<List<SupportedDeviceDescriptor>> _discoveredDevices = ValueNotifier([]);
  ValueNotifier<List<SupportedDeviceDescriptor>> get discoveredDevices => _discoveredDevices;

  DeviceEntity? _lastestAddedDevice;
  DeviceEntity? get lastestAddedDevice => _lastestAddedDevice;

  late final List<DeviceGroupEntity> _availableGroups = [];
  List<DeviceGroupEntity> get availableGroups => _availableGroups;

  String get ssid => _ssid;

  set ssid(String value) {
    if (_ssid != value) {
      _ssid = value;
      _validateForm();
    }
  }

  String? get bssid => _bssid;

  String get password => _password;

  set password(String value) {
    if (_password != value) {
      _password = value;
      _validateForm();
    }
  }

  bool get isSmartConfigEnabled => _isSmartConfigEnabled;
  bool get isFormValid => _isFormValid;
  int get newDeviceCount => _newDeviceCount;
  int get discoveredCount => _discoveredCount;

  DeviceDiscoveryViewModel(
    this._logger,
    this._groupManager,
    this._deviceManager, {
    required super.globalEventBus,
    super.logger,
  }) {
    _deviceAddedEventSub = _deviceManager.deviceEvents.on<NewDeviceEntityAddedEvent>().listen(
      (event) => _onNewDeviceEntityAdded(event),
    );

    _newDeviceFoundEventSub = _deviceManager.deviceEvents.on<NewDeviceFoundEvent>().listen(
      (event) => _onNewDeviceFound(event),
    );
  }

  @override
  Future<void> onInitialize() async {
    try {
      _availableGroups.addAll(await _groupManager.fetchAllGroupsInCurrentScene());
    } finally {}
  }

  @override
  void dispose() {
    if (!super.isDisposed) {
      if (_isDiscovering) {
        stopDiscovery().then((_) {
          _deviceAddedEventSub.cancel();
          _newDeviceFoundEventSub.cancel();
          _discoveredDevices.dispose();
          super.dispose();
        });
      }
    }
  }

  void toggleSmartConfigSwitch(bool? value) async {
    isBusy = true;
    notifyListeners();
    try {
      _isSmartConfigEnabled = value ?? false;
      /*
      if (_isSmartConfigEnabled && _ssid.isEmpty) {
        await aquireWifiInfo();
      }
      */
      _validateForm();
    } catch (e, stackTrace) {
      notifyAppError("$e", error: e, stackTrace: stackTrace);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  void _validateForm() {
    _isFormValid = !_isSmartConfigEnabled || (_ssid.isNotEmpty && _password.isNotEmpty);
    notifyListeners();
  }

  Future<void> startStopDiscovery() async {
    if (_isDiscovering) {
      await stopDiscovery();
    } else {
      await startDiscovery();
    }
  }

  Future<void> startDiscovery() async {
    if (!(!isSmartConfigEnabled || isFormValid) || isDiscovering || super.isBusy) {
      return;
    }

    _newDeviceCount = 0;
    _discoveredCount = 0;
    _discoveredDevices.value = [];
    notifyListeners();

    try {
      await _deviceManager.startDiscovery();

      if (isSmartConfigEnabled) {
        await _provisioner.start(
          ProvisioningRequest.fromStrings(
            ssid: ssid,
            password: password.isEmpty ? null : password,
            reservedData: "borneo-hello",
          ),
        );
      }
    } catch (e, stackTrace) {
      super.notifyAppError('Error occurred while discovering devices: $e', error: e, stackTrace: stackTrace);
      _logger.e('Failed to discovering devices', error: e, stackTrace: stackTrace);
    } finally {
      notifyListeners();
    }
  }

  Future<void> stopDiscovery() async {
    if (!isDiscovering || super.isBusy) {
      return;
    }

    try {
      if (isSmartConfigEnabled) {
        _provisioner.stop();
      }
      await _deviceManager.stopDiscovery();
    } catch (e, stackTrace) {
      super.notifyAppError('Error occurred while stopping discovery: $e', error: e, stackTrace: stackTrace);
    } finally {
      notifyListeners();
    }
  }

  Future<void> aquireWifiInfo() async {
    var status = await Permission.locationWhenInUse.status;
    if (status.isDenied) {
      status = await Permission.locationWhenInUse.request();
    }

    if (status.isGranted) {
      try {
        _ssid = '';
        _bssid = '';
        if (_ssid.startsWith('"') && _ssid.endsWith('"')) {
          _ssid = _ssid.substring(1, _ssid.length - 1);
        }
      } catch (e) {
        rethrow;
      }
    } else {
      throw PermissionDeniedException(
        message:
            'The program requires permission to access WiFi network information; otherwise, the WiFi name needs to be manually entered.',
      );
    }
  }

  Future<void> addNewDevice(SupportedDeviceDescriptor deviceInfo, DeviceGroupEntity? group) async {
    await _deviceManager.addNewDevice(deviceInfo, groupID: group?.id);
  }

  Future<void> _onNewDeviceEntityAdded(NewDeviceEntityAddedEvent event) async {
    try {
      _discoveredDevices.value.removeWhere((x) => x.fingerprint == event.device.fingerprint);
      _discoveredDevices.value = List.from(_discoveredDevices.value);
      _lastestAddedDevice = event.device;
    } finally {
      notifyListeners();
    }
  }

  Future<void> _onNewDeviceFound(NewDeviceFoundEvent event) async {
    try {
      _newDeviceCount += 1;
      _discoveredDevices.value.add(event.device);
      _discoveredDevices.value = List.from(_discoveredDevices.value);
    } finally {
      notifyListeners();
    }
  }

  void clearAddedDevice() {
    _lastestAddedDevice = null;
    notifyListeners();
  }
}
