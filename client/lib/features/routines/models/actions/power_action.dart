import 'package:borneo_app/features/routines/models/actions/routine_action.dart';
import 'package:borneo_app/core/services/devices/i_device_manager.dart';

class PowerAction extends RoutineAction {
  static const String type = "common.power";
  static const String kPrevState = "prevState";

  final bool prevState;

  PowerAction({required super.deviceId, required this.prevState});

  @override
  Future<void> execute(IDeviceManager deviceManager) async {
    final bound = deviceManager.boundDevices.where((d) => d.device.id == deviceId).lastOrNull;
    if (bound == null) {
      return;
    }
    final wotThing = deviceManager.getWotThing(deviceId);
    if (wotThing != null) {
      final isOn = wotThing.getProperty("on");
      if (isOn is bool && isOn) {
        wotThing.setProperty("on", false);
      }
    }
  }

  @override
  Future<void> undo(IDeviceManager deviceManager) async {
    final bound = deviceManager.boundDevices.where((d) => d.device.id == deviceId).lastOrNull;
    if (bound == null) return;

    final wotThing = deviceManager.getWotThing(deviceId);
    if (wotThing != null) {
      final isOn = wotThing.getProperty("on");
      if (isOn is bool && isOn != prevState) {
        wotThing.setProperty("on", prevState);
      }
    }
  }

  Map<String, dynamic> toJson() => {'type': type, RoutineAction.kDeviceID: deviceId, kPrevState: prevState};

  static PowerAction fromJson(Map<String, dynamic> json) =>
      PowerAction(deviceId: json[RoutineAction.kDeviceID] as String, prevState: json[kPrevState] as bool);
}
