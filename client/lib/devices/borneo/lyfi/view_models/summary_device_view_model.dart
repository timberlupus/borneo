import 'package:flutter/foundation.dart';
import 'package:borneo_app/devices/borneo/lyfi/core/wot.dart';
import 'package:borneo_app/devices/borneo/view_models/base_borneo_summary_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:lw_wot/wot.dart';

class LyfiSummaryDeviceViewModel extends BaseBorneoSummaryDeviceViewModel {
  final ValueNotifier<LyfiState?> ledState = ValueNotifier(null);
  final ValueNotifier<LyfiMode?> ledMode = ValueNotifier(null);
  final ValueNotifier<List<int>?> channelBrightness = ValueNotifier(null);
  final ValueNotifier<LyfiDeviceInfo?> lyfiDeviceInfo = ValueNotifier(null);

  LyfiSummaryDeviceViewModel(
    super.deviceEntity,
    super.deviceManager,
    super.globalEventBus, {
    required super.gt,
    super.logger,
  });

  @override
  void dispose() {
    if (!isDisposed) {
      wotThing?.removeSubscriber(_onStateChanged);
      wotThing?.removeSubscriber(_onModeChanged);
      wotThing?.removeSubscriber(_onColorChanged);
      wotThing?.removeSubscriber(_onDeviceInfoChanged);
      ledState.dispose();
      ledMode.dispose();
      channelBrightness.dispose();
      lyfiDeviceInfo.dispose();
      super.dispose();
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

  void _onColorChanged(WotMessage msg) {
    final color = wotThing?.getProperty<List<int>>('color');
    if (color != null) {
      channelBrightness.value = List<int>.from(color);
    }
  }

  void _onDeviceInfoChanged(WotMessage msg) {
    final info = wotThing?.getProperty<LyfiDeviceInfo>('lyfiDeviceInfo');
    if (info != null) {
      lyfiDeviceInfo.value = info;
    }
  }

  @override
  void onWotThingChanged(WotThing? oldThing, WotThing? newThing) {
    super.onWotThingChanged(oldThing, newThing);
    oldThing?.removeSubscriber(_onStateChanged);
    oldThing?.removeSubscriber(_onModeChanged);
    oldThing?.removeSubscriber(_onColorChanged);
    oldThing?.removeSubscriber(_onDeviceInfoChanged);
    newThing?.addSubscriber(_onStateChanged);
    newThing?.addSubscriber(_onModeChanged);
    newThing?.addSubscriber(_onColorChanged);
    newThing?.addSubscriber(_onDeviceInfoChanged);
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

    final color = wotThing?.getProperty<List<int>>('color');
    if (color != null) {
      channelBrightness.value = List<int>.from(color);
    }

    final info = wotThing?.getProperty<LyfiDeviceInfo>('lyfiDeviceInfo');
    if (info != null) {
      lyfiDeviceInfo.value = info;
    }
  }
}
