import 'dart:async';

import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';
import 'package:borneo_app/core/services/group_manager_impl.dart';

abstract class IGroupManager {
  bool get isInitialized;

  IGroupManager();

  // Factory constructor to create the implementation
  factory IGroupManager.create(Logger logger, EventBus globalBus, Database db, ISceneManager scenes) {
    return GroupManagerImpl(logger, globalBus, db, scenes);
  }

  // Abstract methods
  Future<void> initialize();
  Future<void> create({required String name, String notes = '', Transaction? tx});
  Future<void> update(String id, {required String name, String notes = '', Transaction? tx});
  Future<void> delete(String id, {Transaction? tx});
  Future<DeviceGroupEntity> fetch(String id, {Transaction? tx});
  Future<List<DeviceGroupEntity>> fetchAllGroupsInCurrentScene({Transaction? tx});
}
