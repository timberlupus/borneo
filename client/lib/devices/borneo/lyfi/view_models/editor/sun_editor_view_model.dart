import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/base_editor_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

class SunEditorViewModel extends BaseEditorViewModel {
  ILyfiDeviceApi get _deviceApi => parent.boundDevice!.driver as ILyfiDeviceApi;

  @override
  bool get canEdit =>
      parent.isOnline && parent.isOn && parent.mode == LedRunningMode.sun && parent.ledState == LedState.dimming;

  bool get canChangeColor => canEdit;

  @override
  LyfiDeviceInfo get deviceInfo => parent.lyfiDeviceInfo;

  List<ScheduledInstant> _sunInstants = const [];
  List<ScheduledInstant> get sunInstants => _sunInstants;

  List<SunCurveItem> _sunCurve = const [];

  SunEditorViewModel(super.parent);

  @override
  Future<void> onInitialize() async {
    final lyfiStatus = await _deviceApi.getLyfiStatus(parent.boundDevice!.device);
    assert(lyfiStatus.state == LedState.dimming);
    assert(lyfiStatus.mode == LedRunningMode.sun);
    for (int i = 0; i < parent.lyfiDeviceInfo.channels.length; i++) {
      channels[i].value = lyfiStatus.sunColor[i];
    }

    _sunCurve = await _deviceApi.getSunCurve(parent.boundDevice!.device);

    final instants = await _deviceApi.getSunSchedule(parent.boundDevice!.device);
    _sunInstants = instants;
  }

  @override
  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < channels.length && value != channels[index].value) {
      channels[index].value = value;
      final color = channels.map((x) => x.value).toList();
      super.colorChangeRateLimiter.add(() => _deviceApi.setColor(parent.boundDevice!.device, color));
      isChanged = true;
      for (var i = 0; i < _sunInstants.length; i++) {
        _sunInstants[i].color[index] = (value * _sunCurve[i].brightness).round();
      }
    }
    notifyListeners();
  }

  @override
  Future<void> save() async {
    //do nothing
  }
}
