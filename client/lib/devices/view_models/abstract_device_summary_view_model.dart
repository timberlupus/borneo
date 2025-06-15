import 'dart:async';

import 'package:borneo_app/devices/borneo/lyfi/core/wot.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_app/core/services/device_manager.dart';
import 'package:event_bus/event_bus.dart';

import '../../shared/view_models/base_view_model.dart';

abstract class AbstractDeviceSummaryViewModel extends BaseViewModel with ViewModelEventBusMixin {
  final DeviceManager deviceManager;
  final DeviceEntity deviceEntity;
  var isInitialized = false;

  bool _isOnline;
  bool get isOnline => _isOnline;

  String get name => deviceEntity.name;

  EventBus get deviceEvents => deviceManager.allDeviceEvents;

  late final StreamSubscription<DeviceBoundEvent> _boundEventSub;
  late final StreamSubscription<DeviceRemovedEvent> _removedEventSub;
  late final StreamSubscription<DevicePowerOnOffChangedEvent> _powerEventSub;

  late bool _isPowerOn = false;
  bool get isPowerOn => _isPowerOn;

  AbstractDeviceSummaryViewModel(this.deviceEntity, this.deviceManager, EventBus globalEventBus)
    : _isOnline = deviceManager.isBound(deviceEntity.id) {
    super.globalEventBus = globalEventBus;
    _boundEventSub = deviceManager.allDeviceEvents.on<DeviceBoundEvent>().listen(_onBound);
    _removedEventSub = deviceManager.allDeviceEvents.on<DeviceRemovedEvent>().listen(_onRemoved);
    _powerEventSub = deviceManager.allDeviceEvents.on<DevicePowerOnOffChangedEvent>().listen(_onPowerChanged);

    if (deviceManager.isBound(deviceEntity.id)) {
      final bound = deviceManager.getBoundDevice(deviceEntity.id);
      final wotDevice = bound.wotAdapter.device;
      if (wotDevice.hasCapability("OnOffSwitch")) {
        final onProp = wotDevice.properties[LyfiKnownProperties.kOn];
        if (onProp != null) {
          _isPowerOn = onProp.value as bool;
        }
      }
    }
  }

  @override
  void dispose() {
    _boundEventSub.cancel();
    _removedEventSub.cancel();
    _powerEventSub.cancel();
    super.dispose();
  }

  Future<bool> tryConnect() async {
    return await deviceManager.tryBind(deviceEntity);
  }

  void _onBound(DeviceBoundEvent event) {
    if (event.device.id == deviceEntity.id) {
      _isOnline = true;
      notifyListeners();
    }
  }

  void _onRemoved(DeviceRemovedEvent event) {
    if (event.device.id == deviceEntity.id) {
      _isOnline = false;
      notifyListeners();
    }
  }

  void _onPowerChanged(DevicePowerOnOffChangedEvent event) {
    if (event.device.id == deviceEntity.id) {
      _isPowerOn = event.onOff;
      notifyListeners();
    }
  }
}
