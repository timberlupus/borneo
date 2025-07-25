import 'dart:async';

import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/blob_manager.dart';
import 'package:borneo_app/core/services/devices/i_device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';
import 'package:borneo_app/core/services/scene_manager_impl.dart';

abstract class ISceneManager {
  static const String currentSceneKey = 'status.scenes.current';

  final Logger? logger;

  ISceneManager(this.logger);

  // Factory constructor to create the implementation
  factory ISceneManager.create(
    GettextLocalizations gt,
    Database db,
    EventBus globalEventBus,
    IBlobManager blobManager, {
    Logger? logger,
  }) {
    return SceneManagerImpl(gt, db, globalEventBus, blobManager, logger: logger);
  }

  // Abstract properties
  bool get isInitialized;
  SceneEntity get current;
  SceneEntity? get located;

  // Abstract methods
  Future<void> initialize(GroupManager groupManager, IDeviceManager deviceManager);
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
}
