import 'dart:async';

import 'package:borneo_app/devices/borneo/view_models/base_borneo_summary_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';

class LyfiSummaryDeviceViewModel extends BaseBorneoSummaryDeviceViewModel {
  bool _disposed = false;
  LyfiState? ledState;
  LyfiMode? ledMode;

  late final StreamSubscription<LyfiModeChangedEvent> _modeChangedSub;
  late final StreamSubscription<LyfiStateChangedEvent> _stateChangedSub;

  LyfiSummaryDeviceViewModel(super.deviceEntity, super.deviceManager, super.globalEventBus) {
    _modeChangedSub = deviceManager.allDeviceEvents.on<LyfiModeChangedEvent>().listen((event) {
      if (super.deviceEntity.id == event.device.id) {
        ledMode = event.mode;
        notifyListeners();
      }
    });

    _stateChangedSub = deviceManager.allDeviceEvents.on<LyfiStateChangedEvent>().listen((event) {
      if (super.deviceEntity.id == event.device.id) {
        ledState = event.state;
        notifyListeners();
      }
    });
  }

  @override
  Future<void> onInitialize({CancellationToken? cancelToken}) async {
    if (super.deviceManager.isBound(deviceEntity.id)) {
      final bound = super.deviceManager.getBoundDevice(deviceEntity.id);
      final api = bound.api<ILyfiDeviceApi>();
      ledState = await api.getState(bound.device);
      ledMode = await api.getMode(bound.device);
    }
  }

  @override
  void dispose() {
    if (!_disposed) {
      _stateChangedSub.cancel();
      _modeChangedSub.cancel();
      super.dispose();
      _disposed = true;
    }
  }
}
