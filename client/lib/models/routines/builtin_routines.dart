import 'package:borneo_app/models/routines/actions/led_switch_temporary_mode_action.dart';
import 'package:borneo_app/models/routines/actions/power_action.dart';
import 'package:borneo_app/models/routines/actions/routine_action.dart';
import 'package:borneo_kernel_abstractions/device_capability.dart';
import 'package:borneo_app/models/routines/abstract_routine.dart';
import 'package:borneo_app/services/device_manager.dart';

final class PowerOffAllRoutine extends AbstractBuiltinRoutine {
  PowerOffAllRoutine() : super(name: 'Power off all', iconAssetPath: 'assets/images/routines/icons/power-off.svg');

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability);
  }

  /// Execute routine
  @override
  Future<List<Map<String, dynamic>>> execute(DeviceManager deviceManager) async {
    final steps = <PowerAction>[];
    for (final bound in deviceManager.boundDevices) {
      final api = bound.api<IPowerOnOffCapability>();
      final prevState = await api.getOnOff(bound.device);
      if (prevState) {
        await api.setOnOff(bound.device, false);
        steps.add(PowerAction(deviceId: bound.device.id, prevState: prevState));
      }
    }
    return steps.map((e) => e.toJson()).toList();
  }

  /// Undo routine
  @override
  Future<List<Map<String, dynamic>>> undo(DeviceManager deviceManager) async {
    // 由 RoutineManager 传入历史记录
    // 这里只负责执行 undo
    // 返回已撤销的步骤
    // RoutineManager 会在 undo 完成后清理历史
    // 这里假设 RoutineManager 会传入最新的历史记录
    // 你可以根据实际需要调整参数
    return [];
  }
}

final class FeedModeRoutine extends AbstractBuiltinRoutine {
  FeedModeRoutine() : super(name: 'Feed mode', iconAssetPath: 'assets/images/routines/icons/feed.svg');

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability);
  }

  @override
  Future<List<Map<String, dynamic>>> execute(DeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> undo(DeviceManager deviceManager) async {
    // TODO: implement undo
    return [];
  }
}

final class WaterChangeModeRoutine extends AbstractBuiltinRoutine {
  WaterChangeModeRoutine()
    : super(name: 'Water change mode', iconAssetPath: 'assets/images/routines/icons/water-change.svg');

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability);
  }

  @override
  Future<List<Map<String, dynamic>>> execute(DeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> undo(DeviceManager deviceManager) async {
    // TODO: implement undo
    return [];
  }
}

final class DryScapeModeRoutine extends AbstractBuiltinRoutine {
  DryScapeModeRoutine() : super(name: 'Dry scape mode', iconAssetPath: 'assets/images/routines/icons/dry-scape.svg');

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability);
  }

  @override
  Future<List<Map<String, dynamic>>> execute(DeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }

  @override
  Future<List<Map<String, dynamic>>> undo(DeviceManager deviceManager) async {
    // TODO: implement undo
    return [];
  }
}
