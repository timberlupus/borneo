import 'package:borneo_app/services/device_manager.dart';

import '../base_entity.dart';

abstract class AbstractRoutine with BaseEntity {
  final String id;
  final String name;
  final String iconAssetPath;

  const AbstractRoutine({
    required this.id,
    required this.name,
    required this.iconAssetPath,
  });

  bool checkAvailable(DeviceManager deviceManager);
  Future<void> execute(DeviceManager deviceManager);
}

abstract class AbstractBuiltinRoutine extends AbstractRoutine {
  AbstractBuiltinRoutine({required super.name, required super.iconAssetPath})
    : super(id: BaseEntity.generateID());
}
