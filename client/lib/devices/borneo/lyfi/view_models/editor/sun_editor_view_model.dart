import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/base_editor_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';

class SunEditorViewModel extends BaseEditorViewModel {
  ILyfiDeviceApi get _deviceApi => parent.boundDevice!.driver as ILyfiDeviceApi;

  @override
  bool get canEdit =>
      parent.isOnline && parent.isOn && parent.mode == LedRunningMode.sun && parent.ledState == LedState.dimming;

  bool get canChangeColor => canEdit;

  @override
  LyfiDeviceInfo get deviceInfo => parent.lyfiDeviceInfo;

  late List<ScheduledInstant> _sunInstants;
  List<ScheduledInstant> get sunInstants => _sunInstants;

  SunEditorViewModel(super.parent);

  @override
  Future<void> onInitialize() async {
    final lyfiStatus = await _deviceApi.getLyfiStatus(parent.boundDevice!.device);
    assert(lyfiStatus.state == LedState.dimming);
    assert(lyfiStatus.mode == LedRunningMode.sun);
    for (int i = 0; i < parent.lyfiDeviceInfo.channels.length; i++) {
      channels[i].value = lyfiStatus.sunColor[i];
    }

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
    }
  }

  @override
  Future<void> save() async {
    //do nothing
  }
}
