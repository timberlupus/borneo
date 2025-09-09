import 'package:borneo_app/features/chores/models/actions/chore_action.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

class LedSwitchTemporaryModeAction extends ChoreAction {
  static const String type = "led.switch_temporary_mode";

  LedSwitchTemporaryModeAction({required super.deviceId});

  @override
  Future<void> execute(IDeviceManager deviceManager) async {
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
  Future<void> undo(IDeviceManager deviceManager) async {
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
