import 'package:flutter/foundation.dart';
import 'package:borneo_app/devices/borneo/lyfi/core/wot.dart';
import 'package:borneo_app/devices/borneo/view_models/base_borneo_summary_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/material.dart';
import 'package:lw_wot/wot.dart';

class LyfiSummaryDeviceViewModel extends BaseBorneoSummaryDeviceViewModel {
  // replace ValueNotifiers with simple nullable fields; UI uses Selector
  LyfiState? ledState;
  LyfiMode? ledMode;
  List<int>? channelBrightness;
  LyfiDeviceInfo? lyfiDeviceInfo;

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
      // plain fields don't require disposal
      super.dispose();
    }
  }

  void _onStateChanged(WotMessage msg) {
    if (isDisposed) {
      return;
    }
    final stateValue = wotThing?.getProperty(LyfiKnownProperties.kState);
    if (stateValue != null) {
      final state = LyfiState.fromString(stateValue as String);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ledState != state) {
          ledState = state;
          notifyListeners();
        }
      });
    }
  }

  void _onModeChanged(WotMessage msg) {
    if (isDisposed) {
      return;
    }
    final modeValue = wotThing?.getProperty(LyfiKnownProperties.kMode);
    if (modeValue != null) {
      final mode = LyfiMode.fromString(modeValue as String);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (ledMode != mode) {
          ledMode = mode;
          notifyListeners();
        }
      });
    }
  }

  void _onColorChanged(WotMessage msg) {
    if (isDisposed) {
      return;
    }
    final color = wotThing?.getProperty<List<int>>('color');
    if (color != null) {
      // defer assignment to avoid modifying state during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final newList = List<int>.from(color);
        if (channelBrightness == null || !listEquals(channelBrightness, newList)) {
          channelBrightness = newList;
          notifyListeners();
        }
      });
    }
  }

  void _onDeviceInfoChanged(WotMessage msg) {
    if (isDisposed) {
      return;
    }
    final info = wotThing?.getProperty<LyfiDeviceInfo>('lyfiDeviceInfo');
    if (info != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (lyfiDeviceInfo != info) {
          lyfiDeviceInfo = info;
          notifyListeners();
        }
      });
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
    if (isDisposed) {
      return;
    }

    LyfiState? newState;
    LyfiMode? newMode;
    List<int>? newColor;
    LyfiDeviceInfo? newInfo;

    final stateValue = wotThing?.getProperty(LyfiKnownProperties.kState);
    if (stateValue != null) {
      newState = LyfiState.fromString(stateValue as String);
    }

    final modeValue = wotThing?.getProperty(LyfiKnownProperties.kMode);
    if (modeValue != null) {
      newMode = LyfiMode.fromString(modeValue as String);
    }

    final color = wotThing?.getProperty<List<int>>('color');
    if (color != null) {
      newColor = List<int>.from(color);
    }

    final info = wotThing?.getProperty<LyfiDeviceInfo>('lyfiDeviceInfo');
    if (info != null) {
      newInfo = info;
    }

    if (newState != null || newMode != null || newColor != null || newInfo != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        bool changed = false;
        if (newState != null && ledState != newState) {
          ledState = newState;
          changed = true;
        }
        if (newMode != null && ledMode != newMode) {
          ledMode = newMode;
          changed = true;
        }
        if (newColor != null && (channelBrightness == null || !listEquals(channelBrightness, newColor))) {
          channelBrightness = newColor;
          changed = true;
        }
        if (newInfo != null && lyfiDeviceInfo != newInfo) {
          lyfiDeviceInfo = newInfo;
          changed = true;
        }
        if (changed) notifyListeners();
      });
    }
  }
}
