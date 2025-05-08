import 'package:borneo_app/assets.dart';
import 'package:borneo_app/models/base_entity.dart';
import 'package:borneo_app/models/device_statistics.dart';
import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/models/devices/device_group_entity.dart';
import 'package:borneo_app/models/events.dart';
import 'package:borneo_app/models/scene_entity.dart';
import 'package:borneo_app/services/blob_manager.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/group_manager.dart';
import 'package:borneo_app/services/store_names.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';

class SceneManager {
  static const String currentSceneKey = 'status.scenes.current';

  final GettextLocalizations _gt;
  final Logger? logger;
  final Database _db;
  final EventBus _globalEventBus;
  final IBlobManager _blobManager;
  bool isInitialized = false;

  late final GroupManager _groupManager;
  late final DeviceManager _deviceManager;

  late SceneEntity _current;
  SceneEntity get current => _current;

  SceneEntity? _located;
  SceneEntity? get located => _located;

  SceneManager(this._gt, this._db, this._globalEventBus, this._blobManager, {this.logger});

  Future<void> initialize(GroupManager groupManager, DeviceManager deviceManager) async {
    if (isInitialized) {
      return;
    }
    _groupManager = groupManager;
    _deviceManager = deviceManager;
    return await _db.transaction((tx) async {
      await _ensureCurrentSceneExists(tx);
      isInitialized = true;
      logger?.i('The SceneManager has been initialized.');
    });
  }

  Future<void> _ensureCurrentSceneExists(Transaction tx) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);
    // Check and add internal scenes
    if (await _isEmpty(tx: tx)) {
      final homeImageID = await _blobManager.create(await rootBundle.load(AssetsPath.kHomeSceneImagePath));

      final homeScene = SceneEntity.newDefault().copyWith(
        name: _gt.translate('My Home'),
        imageID: homeImageID,
        imagePath: _blobManager.getPath(homeImageID),
      );
      await store.record(homeScene.id).put(tx, homeScene.toMap());

      final officeImageID = await _blobManager.create(await rootBundle.load(AssetsPath.kOfficeSceneImagePath));
      final officeScene = SceneEntity(
        id: BaseEntity.generateID(),
        name: _gt.translate('My Office'),
        isCurrent: false,
        lastAccessTime: DateTime.now(),
        imageID: officeImageID,
        imagePath: _blobManager.getPath(officeImageID),
      );
      await store.record(officeScene.id).put(tx, officeScene.toMap());
      _current = homeScene;
    } else {
      _current = await _fetchCurrent(tx);
    }
  }

  Future<bool> _isEmpty({Transaction? tx}) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);
    if (tx == null) {
      return await _db.transaction((tx) async => await store.count(tx) <= 0);
    } else {
      return await store.count(tx) <= 0;
    }
  }

  Future<SceneEntity> _fetchCurrent(Transaction tx) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);
    final finder = Finder(limit: 1, filter: Filter.equals(SceneEntity.kIsCurrent, true));
    final currentRecord = await store.findFirst(tx, finder: finder);
    if (currentRecord == null) {
      logger?.e('Failed to find current scene!');
      throw KeyNotFoundException(message: 'There was no current scene!');
    }
    return SceneEntity.fromMap(currentRecord.key, currentRecord.value);
  }

  Future<SceneEntity> single(String key, {Transaction? tx}) async {
    assert(isInitialized);

    if (tx == null) {
      return await _db.transaction((tx) => single(key, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.scenes);
      final map = (await store.record(key).get(tx))!;
      return SceneEntity.fromMap(key, map);
    }
  }

  Future<List<SceneEntity>> all({Transaction? tx}) async {
    assert(isInitialized);
    if (tx == null) {
      return await _db.transaction((tx2) => all(tx: tx2));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.scenes);
      final records = await store.find(tx);
      final scenes = records.map((record) => SceneEntity.fromMap(record.key, record.value)).toList();
      return scenes;
    }
  }

  Future<DeviceStatistics> getDeviceStatistics(String sceneID) async {
    assert(isInitialized);
    return await _db.transaction((tx) async {
      var activeDevice = 0;
      for (final bound in _deviceManager.boundDevices) {
        final device = bound.device as DeviceEntity;
        if (device.sceneID == sceneID) {
          activeDevice += 1;
        }
      }
      final deviceStore = stringMapStoreFactory.store(StoreNames.devices);
      final totlaDeviceCount = await deviceStore.count(
        tx,
        filter: Filter.equals(DeviceEntity.kSceneIDFieldName, sceneID),
      );
      return DeviceStatistics(totlaDeviceCount, activeDevice);
    });
  }

  Future<SceneEntity> changeCurrent(String newSceneID) async {
    assert(isInitialized);
    if (newSceneID == current.id) {
      throw ArgumentError('Failed to change current scene, they are the same.', 'newSceneID');
    }

    final store = stringMapStoreFactory.store(StoreNames.scenes);
    return await _db.transaction((tx) async {
      // Update the old one
      await store.record(_current.id).update(tx, {
        SceneEntity.kLastAccessTime: DateTime.now().millisecondsSinceEpoch,
        SceneEntity.kIsCurrent: false,
      });
      // Update the new one
      await store.record(newSceneID).update(tx, {
        SceneEntity.kLastAccessTime: DateTime.now().millisecondsSinceEpoch,
        SceneEntity.kIsCurrent: true,
      });
      // Load the new one
      final newCurrentRecord = await store.record(newSceneID).get(tx);
      if (newCurrentRecord == null) {
        throw KeyNotFoundException(message: 'Failed to found current scene ID `$newSceneID`');
      }
      final fromScene = _current;
      final toScene = SceneEntity.fromMap(newSceneID, newCurrentRecord);
      _current = toScene;
      _globalEventBus.fire(CurrentSceneChangedEvent(fromScene, toScene));
      return toScene;
    });
  }

  Future<SceneEntity> create({required String name, required String notes}) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);
    return await _db.transaction((tx) async {
      // TODO make it current
      final scene = SceneEntity(
        id: BaseEntity.generateID(),
        name: name,
        isCurrent: false,
        lastAccessTime: DateTime.now(),
        notes: notes,
      );
      await store.record(scene.id).put(tx, scene.toMap());
      _globalEventBus.fire(SceneCreatedEvent(scene));
      return scene;
    });
  }

  Future<SceneEntity> update({required String id, required String name, required String notes, Transaction? tx}) async {
    if (tx == null) {
      return await _db.transaction((tx) => update(id: id, name: name, notes: notes, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.scenes);
      final record = await store.record(id).update(tx, {
        SceneEntity.kNameField: name,
        SceneEntity.kNotesFieldName: notes,
      });
      if (record == null) {
        throw InvalidOperationException(message: 'Failed to update record');
      }
      final scene = SceneEntity.fromMap(id, record);
      _globalEventBus.fire(SceneUpdatedEvent(scene));
      return scene;
    }
  }

  Future<void> delete(String id, {Transaction? tx}) async {
    if (tx == null) {
      await _db.transaction((tx) => delete(id, tx: tx));
    } else {
      logger?.i('Begin deleting the scene id=`$id`');

      final deviceStore = stringMapStoreFactory.store(StoreNames.devices);
      final deviceRecordsToDelete = await deviceStore.find(
        tx,
        finder: Finder(filter: Filter.equals(DeviceEntity.kSceneIDFieldName, id)),
      );

      for (final deviceRecord in deviceRecordsToDelete) {
        await _deviceManager.delete(deviceRecord.key, tx: tx);
      }

      final groupStore = stringMapStoreFactory.store(StoreNames.groups);
      final groupRecordsToDelete = await groupStore.find(
        tx,
        finder: Finder(filter: Filter.equals(DeviceGroupEntity.kSceneIDFieldName, id)),
      );

      for (final groupRecord in groupRecordsToDelete) {
        await _groupManager.delete(groupRecord.key, tx: tx);
      }

      final sceneStore = stringMapStoreFactory.store(StoreNames.scenes);
      final sceneRecordToDelete = await sceneStore.record(id).get(tx);

      // Delete image
      if (sceneRecordToDelete?[SceneEntity.kImageIDFieldName] != null) {
        await _blobManager.delete(sceneRecordToDelete![SceneEntity.kImageIDFieldName] as String);
      }

      // Delete the group record
      await sceneStore.record(id).delete(tx);
      _globalEventBus.fire(SceneDeletedEvent(id));
    }
  }
}
