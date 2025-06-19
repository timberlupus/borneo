import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/base_editor_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';

class ManualEditorViewModel extends BaseEditorViewModel {
  @override
  bool get canEdit => parent.isOnline && parent.isOn && parent.mode == LyfiMode.manual;

  bool get canChangeColor => canEdit;

  ManualEditorViewModel(super.parent);

  @override
  Future<void> onInitialize({CancellationToken? cancelToken}) async {
    final lyfiStatus = await super.deviceApi.getLyfiStatus(parent.boundDevice!.device, cancelToken: cancelToken);
    assert(lyfiStatus.state == LyfiState.dimming);
    assert(lyfiStatus.mode == LyfiMode.manual);
    for (int i = 0; i < parent.lyfiDeviceInfo.channels.length; i++) {
      channels[i].value = lyfiStatus.manualColor[i];
    }
  }

  @override
  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < super.channels.length && value != super.channels[index].value) {
      super.channels[index].value = value;
      final color = super.channels.map((x) => x.value).toList();
      super.colorChangeRateLimiter.add(() => super.deviceApi.setColor(super.parent.boundDevice!.device, color));
      super.isChanged = true;
    }
  }

  @override
  Future<void> save() async {
    //do nothing
  }
}
