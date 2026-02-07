import 'package:flutter/foundation.dart';
import 'package:borneo_app/devices/borneo/lyfi/core/wot.dart';
import 'package:borneo_app/devices/borneo/view_models/base_borneo_summary_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:lw_wot/wot.dart';

class LyfiSummaryDeviceViewModel extends BaseBorneoSummaryDeviceViewModel {
  bool _disposed = false;
  final ValueNotifier<LyfiState?> ledState = ValueNotifier(null);
  final ValueNotifier<LyfiMode?> ledMode = ValueNotifier(null);

  LyfiSummaryDeviceViewModel(super.deviceEntity, super.deviceManager, super.globalEventBus) {
    _syncFromThing();
    wotThing?.addSubscriber(_onStateChanged);
    wotThing?.addSubscriber(_onModeChanged);
  }

  @override
  void dispose() {
    if (!_disposed) {
      wotThing?.removeSubscriber(_onStateChanged);
      wotThing?.removeSubscriber(_onModeChanged);
      ledState.dispose();
      ledMode.dispose();
      super.dispose();
      _disposed = true;
    }
  }

  void _onStateChanged(WotMessage msg) {
    final stateValue = wotThing?.getProperty(LyfiKnownProperties.kState);
    if (stateValue != null) {
      final state = LyfiState.fromString(stateValue as String);
      ledState.value = state;
    }
  }

  void _onModeChanged(WotMessage msg) {
    final modeValue = wotThing?.getProperty(LyfiKnownProperties.kMode);
    if (modeValue != null) {
      final mode = LyfiMode.fromString(modeValue as String);
      ledMode.value = mode;
    }
  }

  @override
  void onWotThingChanged(WotThing? oldThing, WotThing? newThing) {
    oldThing?.removeSubscriber(_onStateChanged);
    oldThing?.removeSubscriber(_onModeChanged);
    newThing?.addSubscriber(_onStateChanged);
    newThing?.addSubscriber(_onModeChanged);
    _syncFromThing();
  }

  void _syncFromThing() {
    final stateValue = wotThing?.getProperty(LyfiKnownProperties.kState);
    if (stateValue != null) {
      final state = LyfiState.fromString(stateValue as String);
      ledState.value = state;
    }

    final modeValue = wotThing?.getProperty(LyfiKnownProperties.kMode);
    if (modeValue != null) {
      final mode = LyfiMode.fromString(modeValue as String);
      ledMode.value = mode;
    }
  }
}
