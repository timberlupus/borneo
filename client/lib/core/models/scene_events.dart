import 'package:borneo_app/core/models/scene_entity.dart';

sealed class CurrentSceneChangedEvent {
  final SceneEntity newScene;
  const CurrentSceneChangedEvent(this.newScene);
}
