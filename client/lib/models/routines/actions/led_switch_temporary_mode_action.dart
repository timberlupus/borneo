import 'package:borneo_app/models/routines/actions/routine_action.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

class LedSwitchTemporaryModeAction extends RoutineAction {
  static const String type = "led.switch_temporary_mode";

  LedSwitchTemporaryModeAction({required super.deviceId});

  @override
  Future<void> execute(DeviceManager deviceManager) async {
    final bound = deviceManager.boundDevices.where((d) => d.device.id == deviceId).lastOrNull;
    if (bound == null) return;
    final api = bound.api<ILyfiDeviceApi>();
    final state = await api.getState(bound.device);
    final isOn = await api.getOnOff(bound.device);
    if (isOn && state == LyfiState.normal) {
      await api.switchState(bound.device, LyfiState.temporary);
    }
  }

  @override
  Future<void> undo(DeviceManager deviceManager) async {
    final bound = deviceManager.boundDevices.where((d) => d.device.id == deviceId).lastOrNull;
    if (bound == null) {
      return;
    }
    final api = bound.api<ILyfiDeviceApi>();
    final state = await api.getState(bound.device);
    final isOn = await api.getOnOff(bound.device);
    if (isOn && state == LyfiState.temporary) {
      await api.switchState(bound.device, LyfiState.normal);
    }
  }

  Map<String, dynamic> toJson() => {'type': type, 'deviceId': deviceId};

  static LedSwitchTemporaryModeAction fromJson(Map<String, dynamic> json) =>
      LedSwitchTemporaryModeAction(deviceId: json['deviceId'] as String);
}
