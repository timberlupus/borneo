import '../../../core/models/scene_entity.dart';

final class SceneEditArguments {
  final bool isCreation;
  final SceneEntity? model;
  const SceneEditArguments({required this.isCreation, this.model});
}
