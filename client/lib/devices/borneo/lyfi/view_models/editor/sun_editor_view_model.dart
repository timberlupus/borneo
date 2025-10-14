import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/base_editor_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';

class SunEditorViewModel extends BaseEditorViewModel {
  ILyfiDeviceApi get _deviceApi => parent.boundDevice!.driver as ILyfiDeviceApi;

  @override
  bool get canEdit => parent.isOnline && parent.isOn && parent.mode == LyfiMode.sun;

  bool get canChangeColor => canEdit;

  @override
  LyfiDeviceInfo get deviceInfo => parent.lyfiDeviceInfo;

  ScheduleTable _sunInstants = const [];
  ScheduleTable get sunInstants => _sunInstants;

  List<SunCurveItem> _sunCurve = const [];

  SunEditorViewModel(super.parent);

  @override
  Future<void> onInitialize({CancellationToken? cancelToken}) async {
    // Ensure we are in the correct state and mode before proceeding
    if (parent.state != LyfiState.dimming) {
      throw StateError('SunEditorViewModel requires parent state to be dimming, but current state is ${parent.state}');
    }
    assert(parent.mode == LyfiMode.sun);

    final lyfiStatus = await _deviceApi.getLyfiStatus(parent.boundDevice!.device, cancelToken: cancelToken);
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
      await super.syncDimmingColor(true);
      super.isChanged = true;
      for (var i = 0; i < _sunInstants.length; i++) {
        _sunInstants[i].color[index] = (value * _sunCurve[i].brightness).round();
      }
    }
    super.notifyListeners();
  }

  @override
  Future<void> save() async {
    //do nothing
  }
}
