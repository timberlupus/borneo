import 'dart:async';

import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/models/devices/device_state.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:event_bus/event_bus.dart';

import '/view_models/base_view_model.dart';

class DeviceSummaryViewModel extends BaseViewModel with ViewModelEventBusMixin {
  final DeviceEntity deviceEntity;

  final DeviceManager _deviceManager;

  bool _isOnline;
  bool get isOnline => _isOnline;

  final DeviceState _state;
  DeviceState get state => _state;

  String get id => deviceEntity.id;
  String get name => deviceEntity.name;

  late final StreamSubscription<DeviceBoundEvent> _boundEventSub;
  late final StreamSubscription<DeviceRemovedEvent> _removedEventSub;

  DeviceSummaryViewModel(
    this.deviceEntity,
    DeviceState initialState,
    this._deviceManager,
    EventBus globalEventBus,
  ) : _isOnline = _deviceManager.isBound(deviceEntity.id),
      _state = initialState {
    super.globalEventBus = globalEventBus;
    _boundEventSub = _deviceManager.deviceEvents.on<DeviceBoundEvent>().listen(
      _onBound,
    );
    _removedEventSub = _deviceManager.deviceEvents
        .on<DeviceRemovedEvent>()
        .listen(_onRemoved);
  }

  @override
  void dispose() {
    _boundEventSub.cancel();
    _removedEventSub.cancel();

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
}
