import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/ieditor.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/material.dart';

class MoonEditorViewModel extends ChangeNotifier implements IEditor {
  final BaseLyfiDeviceViewModel parent;
  final List<ValueNotifier<int>> _channels;
  final List<int> blackColor;

  ILyfiDeviceApi get _deviceApi => parent.boundDevice!.driver as ILyfiDeviceApi;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  bool get isOnline => parent.isOnline && !parent.isSuspectedOffline;
  bool get isBusy => parent.isBusy;

  bool _isChanged = false;

  @override
  bool get isChanged => _isChanged;

  set isChanged(bool newValue) => _isChanged = newValue;

  @override
  List<ValueNotifier<int>> get channels => _channels;

  @override
  int get availableChannelCount => parent.lyfiDeviceInfo.channelCount;

  @override
  LyfiDeviceInfo get deviceInfo => parent.lyfiDeviceInfo;

  @override
  bool get canEdit => parent.isOnline && !parent.isSuspectedOffline && parent.isOn;

  bool get canChangeColor => canEdit;

  ScheduleTable _moonInstants = const [];
  ScheduleTable get moonInstants => _moonInstants;

  final List<MoonCurveItem> moonCurve;

  MoonEditorViewModel(this.parent)
    : _channels = List.generate(parent.lyfiDeviceInfo.channelCount, growable: false, (index) => ValueNotifier(0)),
      moonCurve = parent.lyfiThing.getProperty<List<MoonCurveItem>>('moonCurve')!,
      blackColor = List.filled(parent.lyfiDeviceInfo.channelCount, 0, growable: false);

  @override
  Future<void> initialize({CancellationToken? cancelToken}) async {
    try {
      await onInitialize(cancelToken: cancelToken);
    } finally {
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> onInitialize({CancellationToken? cancelToken}) async {
    if (parent.boundDevice == null) {
      throw StateError('Device is not bound.');
    }

    final moonConfig = parent.lyfiThing.getProperty<MoonConfig>('moonConfig')!;
    for (int i = 0; i < parent.lyfiDeviceInfo.channels.length; i++) {
      channels[i].value = moonConfig.color[i];
    }

    final instants = await _deviceApi.getMoonSchedule(parent.boundDevice!.device, cancelToken: cancelToken);
    _moonInstants = instants;
  }

  @override
  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < channels.length && value != channels[index].value) {
      channels[index].value = value;
      for (int i = 0; i < _moonInstants.length; i++) {
        final illum = moonCurve[i].brightness;
        _moonInstants[i].color[index] = (value * illum).round();
      }
      isChanged = true;
    }
    notifyListeners();
  }

  @override
  Future<void> save({CancellationToken? cancelToken}) async {
    if (parent.isSuspectedOffline || parent.boundDevice == null) {
      return;
    }
  }
}
