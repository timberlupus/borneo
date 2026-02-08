import 'package:borneo_app/features/chores/models/actions/led_switch_temporary_mode_action.dart';
import 'package:borneo_app/features/chores/models/actions/power_action.dart';
import 'package:borneo_app/features/chores/models/actions/chore_action.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';

import '../../../shared/models/base_entity.dart';

abstract class AbstractChore with BaseEntity {
  final String id;
  final String name;
  final String iconAssetPath;

  final List<String> requiredCapabilities;

  const AbstractChore({
    required this.id,
    required this.name,
    required this.iconAssetPath,
    required this.requiredCapabilities,
  });

  bool checkAvailable(SceneEntity scene, IDeviceManager deviceManager) {
    final devices = deviceManager.getBoundDevicesInCurrentScene();
    final isAvailable = devices.any((d) => matchAllCapabilities(d, deviceManager));

    return isAvailable;
  }

  ChoreAction createAction(Map<String, dynamic> e) => switch (e['type']) {
    PowerAction.type => PowerAction.fromJson(e),
    LedSwitchTemporaryModeAction.type => LedSwitchTemporaryModeAction.fromJson(e),
    _ => throw UnimplementedError('Unknown chore action type: `${e['type']}`'),
  };

  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, IDeviceManager deviceManager);

  bool matchAllCapabilities(BoundDevice bound, IDeviceManager deviceManager) {
    return requiredCapabilities.every((capability) => _hasCapability(bound, capability, deviceManager));
  }

  bool _hasCapability(BoundDevice bound, String capability, IDeviceManager deviceManager) {
    final wotThing = deviceManager.getWotThing(bound.device.id);

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

abstract class AbstractBuiltinChore extends AbstractChore {
  AbstractBuiltinChore({required super.name, required super.iconAssetPath, required super.requiredCapabilities})
    : super(id: BaseEntity.generateID());
}
