import 'package:borneo_app/features/routines/models/actions/led_switch_temporary_mode_action.dart';
import 'package:borneo_app/features/routines/models/actions/power_action.dart';
import 'package:borneo_app/features/routines/models/actions/routine_action.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';

import '../../../shared/models/base_entity.dart';

abstract class AbstractRoutine with BaseEntity {
  final String id;
  final String name;
  final String iconAssetPath;

  final List<String> requiredCapabilities;

  const AbstractRoutine({
    required this.id,
    required this.name,
    required this.iconAssetPath,
    required this.requiredCapabilities,
  });

  bool checkAvailable(SceneEntity scene, DeviceManager deviceManager) {
    final devices = deviceManager.getBoundDevicesInCurrentScene();
    final isAvailable = devices.any((d) => matchAllCapabilities(d, deviceManager));

    return isAvailable;
  }

  RoutineAction createAction(Map<String, dynamic> e) => switch (e['type']) {
    PowerAction.type => PowerAction.fromJson(e),
    LedSwitchTemporaryModeAction.type => LedSwitchTemporaryModeAction.fromJson(e),
    _ => throw UnimplementedError('Unknown routine action type: `${e['type']}`'),
  };

  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, DeviceManager deviceManager);

  bool matchAllCapabilities(BoundDevice bound, DeviceManager deviceManager) {
    return requiredCapabilities.every((capability) => _hasCapability(bound, capability, deviceManager));
  }

  bool _hasCapability(BoundDevice bound, String capability, DeviceManager deviceManager) {
    final wotThing = deviceManager.getWotThing(bound.device.id);
    if (wotThing == null) return false;

    final types = wotThing.getType();
    if (types.contains(capability)) return true;

    // Check for capability-specific properties that indicate the capability
    switch (capability) {
      case "OnOffSwitch":
        return wotThing.hasProperty("on");
      case "LyfiDevice":
        return wotThing.hasProperty("state") && wotThing.hasProperty("mode");
      default:
        return false;
    }
  }
}

abstract class AbstractBuiltinRoutine extends AbstractRoutine {
  AbstractBuiltinRoutine({required super.name, required super.iconAssetPath, required super.requiredCapabilities})
    : super(id: BaseEntity.generateID());
}
