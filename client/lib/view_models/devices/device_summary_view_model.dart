import 'dart:async';

import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/models/devices/device_state.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_app/services/device_manager.dart';

import '/view_models/base_view_model.dart';

class DeviceSummaryViewModel extends BaseViewModel {
  final DeviceEntity deviceEntity;

  bool _isOnline;
  bool get isOnline => _isOnline;

  final DeviceState _state;
  DeviceState get state => _state;

  String get id => deviceEntity.id;
  String get name => deviceEntity.name;

  late final StreamSubscription<DeviceBoundEvent> _boundEventSub;
  late final StreamSubscription<DeviceRemovedEvent> _removedEventSub;

  DeviceSummaryViewModel(
      this.deviceEntity, DeviceState initialState, DeviceManager dm)
      : _isOnline = dm.isBound(deviceEntity.id),
        _state = initialState {
    _boundEventSub = dm.deviceEvents.on<DeviceBoundEvent>().listen(_onBound);
    _removedEventSub =
        dm.deviceEvents.on<DeviceRemovedEvent>().listen(_onRemoved);
  }

  @override
  void dispose() {
    _boundEventSub.cancel();
    _removedEventSub.cancel();

    super.dispose();
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
}
