import 'dart:async';

import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/models/devices/device_state.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel_abstractions/device_capability.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:event_bus/event_bus.dart';

import '/view_models/base_view_model.dart';
import 'package:borneo_app/services/devices/device_module_registry.dart';
import 'package:borneo_app/models/devices/device_module_metadata.dart';

class DeviceSummaryViewModel extends BaseViewModel with ViewModelEventBusMixin {
  final DeviceEntity deviceEntity;
  final DeviceManager _deviceManager;
  final IDeviceModuleRegistry _deviceModuleRegistry;

  bool _isOnline;
  bool get isOnline => _isOnline;

  final DeviceState _state;
  DeviceState get state => _state;

  String get id => deviceEntity.id;
  String get name => deviceEntity.name;

  DeviceModuleMetadata? get deviceModuleMetadata => _deviceModuleRegistry.metaModules[deviceEntity.driverID];

  EventBus get deviceEvents => _deviceManager.deviceEvents;

  late final StreamSubscription<DeviceBoundEvent> _boundEventSub;
  late final StreamSubscription<DeviceRemovedEvent> _removedEventSub;
  late bool _isPowerOn = false;
  bool get isPowerOn => _isPowerOn;
  late final StreamSubscription<DevicePowerOnOffChangedEvent> _powerEventSub;

  DeviceSummaryViewModel(
    this.deviceEntity,
    DeviceState initialState,
    this._deviceManager,
    this._deviceModuleRegistry,
    EventBus globalEventBus,
    this._isPowerOn,
  ) : _isOnline = _deviceManager.isBound(deviceEntity.id),
      _state = initialState {
    super.globalEventBus = globalEventBus;
    _boundEventSub = _deviceManager.deviceEvents.on<DeviceBoundEvent>().listen(_onBound);
    _removedEventSub = _deviceManager.deviceEvents.on<DeviceRemovedEvent>().listen(_onRemoved);
    _powerEventSub = _deviceManager.deviceEvents.on<DevicePowerOnOffChangedEvent>().listen(_onPowerChanged);

    /*
if( _deviceManager.boundDevices.contains(this.deviceEntity.id)) {
  final bound = _deviceManager.getBoundDevice(this.deviceEntity.id).api() as IPowerOnOffCapability;
  bound.getOnOff(dev)
}
    if(deviceEntity.id)

    if(_deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability)
    if(this.deviceEntity )
    _isPowerOn = true;
    */
  }

  @override
  void dispose() {
    _boundEventSub.cancel();
    _removedEventSub.cancel();
    _powerEventSub.cancel();
    super.dispose();
  }

  Future<bool> tryConnect() async {
    return await _deviceManager.tryBind(deviceEntity);
  }

  void _onBound(DeviceBoundEvent event) {
    if (event.device.id == id) {
      _isOnline = true;
      notifyListeners();
    }
  }

  void _onRemoved(DeviceRemovedEvent event) {
    if (event.device.id == id) {
      _isOnline = false;
      notifyListeners();
    }
  }

  void _onPowerChanged(DevicePowerOnOffChangedEvent event) {
    if (event.device.id == id) {
      _isPowerOn = event.onOff;
      notifyListeners();
    }
  }
}
