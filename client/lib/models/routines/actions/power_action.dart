import 'package:borneo_app/models/routines/actions/routine_action.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_kernel_abstractions/device_capability.dart';

class PowerAction extends RoutineAction {
  static const String type = "common.power";
  static const String kPrevState = "prevState";

  final bool prevState;

  PowerAction({required super.deviceId, required this.prevState});

  @override
  Future<void> execute(DeviceManager deviceManager) async {
    final bound = deviceManager.boundDevices.where((d) => d.device.id == deviceId).lastOrNull;
    if (bound == null) {
      return;
    }
    final api = bound.api<IPowerOnOffCapability>();
    final isOn = await api.getOnOff(bound.device);
    if (isOn) {
      await api.setOnOff(bound.device, false);
    }
  }

  @override
  Future<void> undo(DeviceManager deviceManager) async {
    final bound = deviceManager.boundDevices.where((d) => d.device.id == deviceId).lastOrNull;
    if (bound == null) return;
    final api = bound.api<IPowerOnOffCapability>();

    final isOn = await api.getOnOff(bound.device);
    if (isOn != prevState) {
      await api.setOnOff(bound.device, prevState);
    }
  }

  Map<String, dynamic> toJson() => {'type': type, RoutineAction.kDeviceID: deviceId, kPrevState: prevState};

  static PowerAction fromJson(Map<String, dynamic> json) =>
      PowerAction(deviceId: json[RoutineAction.kDeviceID] as String, prevState: json[kPrevState] as bool);
}
