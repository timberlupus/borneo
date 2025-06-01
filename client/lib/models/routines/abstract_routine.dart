import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/routine_history_store.dart';

import '../base_entity.dart';

abstract class AbstractRoutine with BaseEntity {
  final String id;
  final String name;
  final String iconAssetPath;

  const AbstractRoutine({required this.id, required this.name, required this.iconAssetPath});

  bool checkAvailable(DeviceManager deviceManager);
  Future<void> execute(DeviceManager deviceManager);

  /// 反向操作接口，默认无操作
  Future<void> undo(DeviceManager deviceManager) async {}
}

abstract class AbstractBuiltinRoutine extends AbstractRoutine {
  AbstractBuiltinRoutine({required super.name, required super.iconAssetPath}) : super(id: BaseEntity.generateID());
}

/// 需要持久化历史的 Routine 可实现此 mixin
mixin PersistentRoutineMixin on AbstractRoutine {
  Future<void> executeAndPersist(DeviceManager deviceManager, RoutineHistoryStore store, String routineId);
  Future<void> undoFromHistory(DeviceManager deviceManager, RoutineHistoryStore store, String routineId);
}
