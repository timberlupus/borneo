import 'package:borneo_app/models/devices/device_group_entity.dart';
import 'package:borneo_app/models/scene_entity.dart';

final class CurrentSceneChangedEvent {
  final SceneEntity from;
  final SceneEntity to;
  const CurrentSceneChangedEvent(this.from, this.to);
}

final class LocatedSceneChangedEvent {
  final SceneEntity? from;
  final SceneEntity to;
  const LocatedSceneChangedEvent(this.from, this.to);
}

final class SceneCreatedEvent {
  final SceneEntity scene;
  const SceneCreatedEvent(this.scene);
}

final class SceneUpdatedEvent {
  final SceneEntity scene;
  const SceneUpdatedEvent(this.scene);
}

final class SceneDeletedEvent {
  final String id;
  const SceneDeletedEvent(this.id);
}

class DeviceGroupCreatedEvent {
  final DeviceGroupEntity group;
  const DeviceGroupCreatedEvent(this.group);
}

class DeviceGroupUpdatedEvent {
  final DeviceGroupEntity group;
  const DeviceGroupUpdatedEvent(this.group);
}

class DeviceGroupDeletedEvent {
  final String id;
  const DeviceGroupDeletedEvent(this.id);
}
