import 'dart:async';

import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:sembast/sembast.dart';

abstract class ISceneManager {
  static const String currentSceneKey = 'status.scenes.current';

  // Abstract properties
  bool get isInitialized;
  SceneEntity get current;
  SceneEntity? get located;

  // Abstract methods
  Future<void> initialize(IGroupManager groupManager, IDeviceManager deviceManager);
  Future<SceneEntity> single(String key, {Transaction? tx});
  Future<List<SceneEntity>> all({Transaction? tx});
  Future<DeviceStatistics> getDeviceStatistics(String sceneID);
  Future<SceneEntity> changeCurrent(String newSceneID);
  Future<SceneEntity> create({required String name, required String notes, String? imagePath});
  Future<SceneEntity> update({
    required String id,
    required String name,
    required String notes,
    String? imagePath,
    Transaction? tx,
  });
  Future<void> delete(String id, {Transaction? tx});
  Future<SceneEntity> getLastAccessed({CancellationToken? cancelToken});
}
