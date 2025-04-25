import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/ieditor.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_common/async/async_rate_limiter.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/material.dart';

class ManualEditorViewModel extends ChangeNotifier implements IEditor {
  bool _isChanged = false;
  bool _isInitialized = false;
  ILyfiDeviceApi get _deviceApi => _parent.boundDevice!.driver as ILyfiDeviceApi;
  final LyfiViewModel _parent;

  final AsyncRateLimiter<Future Function()> _colorChangeRateLimiter = AsyncRateLimiter(
    interval: localDimmingTrackingInterval,
  );

  final List<ValueNotifier<int>> _channels;

  bool get isInitialized => _isInitialized;
  bool get isBusy => _parent.isBusy;

  @override
  bool get canEdit => !isBusy && _parent.isOnline && _parent.isOn && !_parent.isLocked;

  bool get canChangeColor => canEdit;

  @override
  LyfiDeviceInfo get deviceInfo => _parent.lyfiDeviceInfo;

  ManualEditorViewModel(this._parent)
    : _channels = List.generate(_parent.lyfiDeviceInfo.channelCount, growable: false, (index) => ValueNotifier(0));

  @override
  Future<void> initialize() async {
    _parent.enqueueJob(() async {
      final lyfiStatus = await _deviceApi.getLyfiStatus(_parent.boundDevice!.device);
      for (int i = 0; i < _parent.lyfiDeviceInfo.channels.length; i++) {
        _channels[i].value = lyfiStatus.manualColor[i];
      }

      _isInitialized = true;
      notifyListeners();
    });
  }

  @override
  List<ValueNotifier<int>> get channels => _channels;

  @override
  int get availableChannelCount => deviceInfo.channelCount;

  @override
  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < _channels.length && value != _channels[index].value) {
      _channels[index].value = value;
      final color = _channels.map((x) => x.value).toList();
      _colorChangeRateLimiter.add(() => _deviceApi.setColor(_parent.boundDevice!.device, color));
      _isChanged = true;
    }
  }

  @override
  void dispose() {
    _colorChangeRateLimiter.dispose();
    super.dispose();
  }

  @override
  bool get isChanged => _isChanged;

  @override
  Future<void> save() async {
    //do nothing
  }
}
