import 'package:borneo_app/models/scene_entity.dart';

sealed class CurrentSceneChangedEvent {
  final SceneEntity newScene;
  const CurrentSceneChangedEvent(this.newScene);
}
