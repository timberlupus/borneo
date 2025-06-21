import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/models/device_statistics.dart';

/// Scene 相关的状态类
/// 使用简单的类而不是 Freezed，因为项目中没有 Freezed 依赖

class SceneState {
  final List<SceneEntity> scenes;
  final SceneEntity? currentScene;
  final SceneEntity? locatedScene;
  final bool isLoading;
  final bool isInitialized;
  final String? error;

  const SceneState({
    this.scenes = const [],
    this.currentScene,
    this.locatedScene,
    this.isLoading = false,
    this.isInitialized = false,
    this.error,
  });

  SceneState copyWith({
    List<SceneEntity>? scenes,
    SceneEntity? currentScene,
    SceneEntity? locatedScene,
    bool? isLoading,
    bool? isInitialized,
    String? error,
  }) {
    return SceneState(
      scenes: scenes ?? this.scenes,
      currentScene: currentScene ?? this.currentScene,
      locatedScene: locatedScene ?? this.locatedScene,
      isLoading: isLoading ?? this.isLoading,
      isInitialized: isInitialized ?? this.isInitialized,
      error: error ?? this.error,
    );
  }

  @override
  String toString() {
    return 'SceneState(scenes: ${scenes.length}, currentScene: ${currentScene?.name}, isLoading: $isLoading, isInitialized: $isInitialized, error: $error)';
  }
}

/// Scene 设备统计状态
class SceneDeviceStatistics {
  final String sceneId;
  final DeviceStatistics statistics;
  final bool isLoading;
  final String? error;

  const SceneDeviceStatistics({required this.sceneId, required this.statistics, this.isLoading = false, this.error});

  SceneDeviceStatistics copyWith({String? sceneId, DeviceStatistics? statistics, bool? isLoading, String? error}) {
    return SceneDeviceStatistics(
      sceneId: sceneId ?? this.sceneId,
      statistics: statistics ?? this.statistics,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}
