import 'package:borneo_app/features/chores/models/actions/power_action.dart';
import 'package:borneo_app/features/chores/models/abstract_chore.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/models/scene_entity.dart';

final class PowerOffAllChore extends AbstractBuiltinChore {
  PowerOffAllChore()
    : super(
        name: 'Power off all',
        iconAssetPath: 'assets/images/chores/icons/power-off.svg',
        requiredCapabilities: ["OnOffSwitch"],
      );

  /// Execute chore
  @override
  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, IDeviceManager deviceManager) async {
    final steps = <PowerAction>[];
    for (final wotThing in deviceManager.wotThingsInCurrentScene) {
      final onValue = wotThing.getProperty("on");
      if (onValue != null) {
        final prevState = onValue as bool;
        if (prevState) {
          wotThing.setProperty("on", false);
          steps.add(PowerAction(deviceId: wotThing.id, prevState: prevState));
        }
      }
    }
    return steps.map((e) => e.toJson()).toList();
  }
}

final class FeedModeChore extends AbstractBuiltinChore {
  FeedModeChore()
    : super(
        name: 'Feed mode',
        iconAssetPath: 'assets/images/chores/icons/feed.svg',

        requiredCapabilities: ["OnOffSwitch"],
      );

  @override
  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, IDeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }
}

final class WaterChangeModeChore extends AbstractBuiltinChore {
  WaterChangeModeChore()
    : super(
        name: 'Water change mode',
        iconAssetPath: 'assets/images/chores/icons/water-change.svg',
        requiredCapabilities: ["OnOffSwitch"],
      );

  @override
  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, IDeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }
}

final class DryScapeModeChore extends AbstractBuiltinChore {
  DryScapeModeChore()
    : super(
        name: 'Dry scape mode',
        iconAssetPath: 'assets/images/chores/icons/dry-scape.svg',

        requiredCapabilities: ["OnOffSwitch"],
      );

  @override
  Future<List<Map<String, dynamic>>> execute(SceneEntity currentScene, IDeviceManager deviceManager) async {
    // TODO: implement execute
    return [];
  }
}
