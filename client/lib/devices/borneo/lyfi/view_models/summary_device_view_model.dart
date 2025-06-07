import 'package:borneo_app/devices/borneo/view_models/base_borneo_summary_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';

class LyfiSummaryDeviceViewModel extends BaseBorneoSummaryDeviceViewModel {
  LyfiSummaryDeviceViewModel(super.deviceEntity, super.deviceManager, super.globalEventBus);

  LedState? ledState;
  LedRunningMode? ledMode;

  @override
  Future<void> onInitialize({CancellationToken? cancelToken}) async {
    if (super.deviceManager.isBound(deviceEntity.id)) {
      final bound = super.deviceManager.getBoundDevice(deviceEntity.id);
      final api = bound.api<ILyfiDeviceApi>();
      ledState = await api.getState(bound.device);
      ledMode = await api.getMode(bound.device);
    }
  }
}
