import 'dart:async';

import 'package:borneo_app/devices/borneo/lyfi/core/wot.dart';
import 'package:borneo_app/devices/borneo/view_models/base_borneo_summary_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

class LyfiSummaryDeviceViewModel extends BaseBorneoSummaryDeviceViewModel {
  bool _disposed = false;
  LyfiState? ledState;
  LyfiMode? ledMode;

  late final StreamSubscription<LyfiModeChangedEvent> _modeChangedSub;
  late final StreamSubscription<LyfiStateChangedEvent> _stateChangedSub;

  LyfiSummaryDeviceViewModel(super.deviceEntity, super.deviceManager, super.globalEventBus) {
    _modeChangedSub = deviceManager.allDeviceEvents.on<LyfiModeChangedEvent>().listen((event) {
      if (super.deviceEntity.id == event.device.id) {
        ledMode = event.mode;
        notifyListeners();
      }
    });

    _stateChangedSub = deviceManager.allDeviceEvents.on<LyfiStateChangedEvent>().listen((event) {
      if (super.deviceEntity.id == event.device.id) {
        ledState = event.state;
        notifyListeners();
      }
    });
    if (super.deviceManager.isBound(deviceEntity.id)) {
      final bound = super.deviceManager.getBoundDevice(deviceEntity.id);
      final wotThing = bound.thing;
      final stateValue = wotThing.getProperty(LyfiKnownProperties.kState);
      if (stateValue != null) {
        final state = LyfiState.fromString(stateValue as String);
        ledState = state;
      }

      final modeValue = wotThing.getProperty(LyfiKnownProperties.kMode);
      if (modeValue != null) {
        final mode = LyfiMode.fromString(modeValue as String);
        ledMode = mode;
      }
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      _stateChangedSub.cancel();
      _modeChangedSub.cancel();
      super.dispose();
      _disposed = true;
    }
  }
}
