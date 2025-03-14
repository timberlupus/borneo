import 'package:borneo_app/models/base_entity.dart';
import 'package:borneo_app/models/devices/device_group_entity.dart';
import 'package:borneo_app/models/events.dart';
import 'package:borneo_app/services/scene_manager.dart';
import 'package:borneo_app/services/store_names.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';

import '../models/devices/device_entity.dart';

class GroupManager {
  final Database _db;
  final Logger _logger;
  final EventBus _globalBus;
  final SceneManager _scenes;
  bool isInitialized = false;

  GroupManager(this._logger, this._globalBus, this._db, this._scenes) : isInitialized = false;

  Future<void> initialize() async {
    return await _db.transaction((tx) async {
      //  await _ensureDefaultGroupExists(tx);
      isInitialized = true;
      _logger.i('The GroupManager has been initialized.');
    });
  }

  /*
  Future<void> _ensureDefaultGroupExists(Transaction tx) async {
    final store = stringMapStoreFactory.store(StoreNames.groups);
    final n = await store.count(tx, filter: _makeDefaultGroupFilter());
  }

  Future<DeviceGroupEntity> _fetchDefaultGroup(Transaction tx) async {
    final store = stringMapStoreFactory.store(StoreNames.groups);
    final record = await store.findFirst(tx,
        finder: Finder(filter: _makeDefaultGroupFilter()));
    final defaultGroup = DeviceGroupEntity.fromMap(record!.key, record.value);
    return defaultGroup;
  }

  Future<DeviceGroupEntity> fetchDefaultGroup({Transaction? tx}) async {
    if (tx != null) {
      return await _fetchDefaultGroup(tx);
    } else {
      return await _db.transaction((tx2) async {
        return await _fetchDefaultGroup(tx2);
      });
    }
  }
  */

  Future<void> create({required String name, String notes = '', Transaction? tx}) async {
    if (tx == null) {
      await _db.transaction((tx) async {
        await create(name: name, tx: tx);
      });
    } else {
      final store = stringMapStoreFactory.store(StoreNames.groups);
      final group = DeviceGroupEntity(
        id: BaseEntity.generateID(),
        sceneID: _scenes.current.id,
        name: name,
        notes: notes,
      );
      await store.record(group.id).put(tx, group.toMap());
      _globalBus.fire(DeviceGroupCreatedEvent(group));
    }
  }

  Future<void> update(String id, {required String name, String notes = '', Transaction? tx}) async {
    if (tx == null) {
      await _db.transaction((tx) => update(id, name: name, notes: notes, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.groups);
      final record = await store.record(id).update(tx, {
        DeviceGroupEntity.kNameField: name,
        DeviceGroupEntity.kNotesFieldName: notes,
      });
      if (record == null) {
        throw InvalidOperationException(message: 'Failed to update record');
      }
      final group = DeviceGroupEntity.fromMap(id, record);
      _globalBus.fire(DeviceGroupUpdatedEvent(group));
    }
  }

  Future<void> delete(String id, {Transaction? tx}) async {
    if (tx == null) {
      await _db.transaction((tx) => delete(id, tx: tx));
    } else {
      // Set the `groupID` all the devices to null
      final deviceStore = stringMapStoreFactory.store(StoreNames.devices);
      await deviceStore.update(tx, {
        DeviceEntity.kGroupIDFieldName: null,
      }, finder: Finder(filter: Filter.equals(DeviceEntity.kGroupIDFieldName, id)));
      // Delete the group record
      final groupStore = stringMapStoreFactory.store(StoreNames.groups);
      await groupStore.record(id).delete(tx);
      _globalBus.fire(DeviceGroupDeletedEvent(id));
    }
  }

  Future<List<DeviceGroupEntity>> fetchAllGroupsInCurrentScene({Transaction? tx}) async {
    assert(isInitialized);
    if (tx == null) {
      return await _db.transaction((tx) => fetchAllGroupsInCurrentScene(tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.groups);
      final records = await store.find(
        tx,
        finder: Finder(filter: Filter.equals(DeviceGroupEntity.kSceneIDFieldName, _scenes.current.id)),
      );
      final groups = records.map((record) => DeviceGroupEntity.fromMap(record.key, record.value)).toList();
      return groups;
    }
  }
}
