import 'package:borneo_app/features/routines/models/actions/power_action.dart';
import 'package:borneo_app/features/routines/models/abstract_routine.dart';
import 'package:borneo_app/core/services/device_manager.dart';
import 'package:borneo_app/models/scene_entity.dart';

final class PowerOffAllRoutine extends AbstractBuiltinRoutine {
  PowerOffAllRoutine()
    : super(
        name: 'Power off all',
        iconAssetPath: 'assets/images/routines/icons/power-off.svg',
        requiredCapabilities: ["OnOffSwitch"],
      );

  /// Execute routine
  @override
  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, DeviceManager deviceManager) async {
    final steps = <PowerAction>[];
    for (final bound in deviceManager.boundDevices) {
      final onValue = bound.thing.getProperty("on");
      final prevState = onValue as bool;
      if (prevState) {
        bound.thing.setProperty("on", false);
        steps.add(PowerAction(deviceId: bound.device.id, prevState: prevState));
      }
    }
    return steps.map((e) => e.toJson()).toList();
  }
}

final class FeedModeRoutine extends AbstractBuiltinRoutine {
  FeedModeRoutine()
    : super(
        name: 'Feed mode',
        iconAssetPath: 'assets/images/routines/icons/feed.svg',

        requiredCapabilities: ["OnOffSwitch"],
      );

  @override
  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, DeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }
}

final class WaterChangeModeRoutine extends AbstractBuiltinRoutine {
  WaterChangeModeRoutine()
    : super(
        name: 'Water change mode',
        iconAssetPath: 'assets/images/routines/icons/water-change.svg',
        requiredCapabilities: ["OnOffSwitch"],
      );

  @override
  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, DeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }
}

final class DryScapeModeRoutine extends AbstractBuiltinRoutine {
  DryScapeModeRoutine()
    : super(
        name: 'Dry scape mode',
        iconAssetPath: 'assets/images/routines/icons/dry-scape.svg',

        requiredCapabilities: ["OnOffSwitch"],
      );

  @override
  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, DeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }
}
