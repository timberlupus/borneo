import 'package:borneo_app/models/routines/actions/led_switch_temporary_mode_action.dart';
import 'package:borneo_app/models/routines/actions/power_action.dart';
import 'package:borneo_app/models/routines/actions/routine_action.dart';
import 'package:borneo_app/services/device_manager.dart';

import '../base_entity.dart';

abstract class AbstractRoutine with BaseEntity {
  final String id;
  final String name;
  final String iconAssetPath;

  const AbstractRoutine({required this.id, required this.name, required this.iconAssetPath});

  bool checkAvailable(DeviceManager deviceManager);

  RoutineAction createAction(Map<String, dynamic> e) => switch (e['type']) {
    PowerAction.type => PowerAction.fromJson(e),
    LedSwitchTemporaryModeAction.type => LedSwitchTemporaryModeAction.fromJson(e),
    _ => throw UnimplementedError('Unknown routine action type: \'${e['type']}\''),
  };

  Future<List<Map<String, dynamic>>> execute(DeviceManager deviceManager);
}

abstract class AbstractBuiltinRoutine extends AbstractRoutine {
  AbstractBuiltinRoutine({required super.name, required super.iconAssetPath}) : super(id: BaseEntity.generateID());
}
