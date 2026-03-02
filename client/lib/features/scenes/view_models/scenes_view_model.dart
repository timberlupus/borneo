import '../../../core/models/scene_entity.dart';

class SceneSummaryModel {
  final SceneEntity scene;
  final int totalDeviceCount;
  final int activeDeviceCount;
  final bool isSelected;

  const SceneSummaryModel({
    required this.scene,
    required this.totalDeviceCount,
    required this.activeDeviceCount,
    required this.isSelected,
  });

  String get id => scene.id;
  String get name => scene.name;

  SceneSummaryModel copyWith({SceneEntity? scene, int? totalDeviceCount, int? activeDeviceCount, bool? isSelected}) {
    return SceneSummaryModel(
      scene: scene ?? this.scene,
      totalDeviceCount: totalDeviceCount ?? this.totalDeviceCount,
      activeDeviceCount: activeDeviceCount ?? this.activeDeviceCount,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}
