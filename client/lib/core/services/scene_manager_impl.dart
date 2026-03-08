import 'dart:io';

import 'package:borneo_app/app/assets.dart';
import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/shared/models/base_entity.dart';
import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/blob_manager.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/store_names.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_app/core/exceptions/scene_deletion_exceptions.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';
import 'package:borneo_app/core/services/scene_manager.dart';

class SceneManagerImpl extends ISceneManager {
  static const String currentSceneKey = 'status.scenes.current';

  final Logger? logger;
  final GettextLocalizations _gt;
  final Database _db;
  final EventBus _globalEventBus;
  final IBlobManager _blobManager;
  final IClock clock;
  bool _isInitialized = false;

  late final IDeviceManager _deviceManager;

  late SceneEntity _current;

  SceneEntity? _located;

  SceneManagerImpl(this._gt, this._db, this._globalEventBus, this._blobManager, {required this.clock, this.logger});

  @override
  bool get isInitialized => _isInitialized;

  @override
  SceneEntity get current => _current;

  @override
  SceneEntity? get located => _located;

  @override
  Future<void> initialize(IGroupManager groupManager, IDeviceManager deviceManager) async {
    if (_isInitialized) {
      return;
    }
    _deviceManager = deviceManager;
    return await _db.transaction((tx) async {
      await _ensureCurrentSceneExists(tx);
      _isInitialized = true;
      logger?.i('The SceneManagerImpl has been initialized.');
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
        lastAccessTime: this.clock.now(),
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
    return _restoreSceneImagePath(tx, SceneEntity.fromMap(currentRecord.key, currentRecord.value));
  }

  Future<SceneEntity> _restoreSceneImagePath(Transaction tx, SceneEntity scene) async {
    final imageID = scene.imageID?.trim();
    if (imageID == null || imageID.isEmpty) {
      return scene;
    }

    final resolvedImagePath = _blobManager.getPath(imageID);
    if (scene.imagePath == resolvedImagePath) {
      return scene;
    }

    final store = stringMapStoreFactory.store(StoreNames.scenes);
    await store.record(scene.id).update(tx, {SceneEntity.kImagePathFieldName: resolvedImagePath});
    return scene.copyWith(imagePath: resolvedImagePath);
  }

  Future<String> _createBlobFromFile(String imagePath) async {
    final bytes = await File(imagePath).readAsBytes();
    return _blobManager.create(ByteData.sublistView(bytes));
  }

  Future<({String? imageID, String? imagePath})> _prepareSceneImage(
    String? imagePath, {
    String? existingImageID,
    String? existingImagePath,
  }) async {
    final normalizedImagePath = imagePath?.trim();
    final normalizedExistingImageID = existingImageID?.trim();
    final normalizedExistingImagePath = existingImagePath?.trim();

    if (normalizedImagePath == null || normalizedImagePath.isEmpty) {
      if (normalizedExistingImageID != null && normalizedExistingImageID.isNotEmpty) {
        await _blobManager.delete(normalizedExistingImageID);
      }
      return (imageID: null, imagePath: null);
    }

    if (normalizedExistingImageID != null && normalizedExistingImageID.isNotEmpty) {
      final resolvedExistingPath = _blobManager.getPath(normalizedExistingImageID);
      if (normalizedImagePath == resolvedExistingPath) {
        return (imageID: normalizedExistingImageID, imagePath: resolvedExistingPath);
      }
    } else if (normalizedExistingImagePath == normalizedImagePath) {
      return (imageID: null, imagePath: normalizedExistingImagePath);
    }

    final newImageID = await _createBlobFromFile(normalizedImagePath);
    final newImagePath = _blobManager.getPath(newImageID);

    if (normalizedExistingImageID != null && normalizedExistingImageID.isNotEmpty) {
      await _blobManager.delete(normalizedExistingImageID);
    }

    return (imageID: newImageID, imagePath: newImagePath);
  }

  @override
  Future<SceneEntity> single(String key, {Transaction? tx}) async {
    assert(isInitialized);

    if (tx == null) {
      return await _db.transaction((tx) => single(key, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.scenes);
      final map = (await store.record(key).get(tx))!;
      return _restoreSceneImagePath(tx, SceneEntity.fromMap(key, map));
    }
  }

  @override
  Future<List<SceneEntity>> all({Transaction? tx}) async {
    assert(isInitialized);
    if (tx == null) {
      return await _db.transaction((tx2) => all(tx: tx2));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.scenes);
      final records = await store.find(tx);
      final scenes = <SceneEntity>[];
      for (final record in records) {
        scenes.add(await _restoreSceneImagePath(tx, SceneEntity.fromMap(record.key, record.value)));
      }
      return scenes;
    }
  }

  @override
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

  @override
  Future<SceneEntity> changeCurrent(String newSceneID) async {
    assert(isInitialized);
    if (newSceneID == current.id) {
      throw ArgumentError('Failed to change current scene, they are the same.', 'newSceneID');
    }

    final store = stringMapStoreFactory.store(StoreNames.scenes);
    return await _db.transaction((tx) async {
      // Update the old one
      final oldUpdate = await store.record(_current.id).update(tx, {
        SceneEntity.kLastAccessTime: this.clock.now().millisecondsSinceEpoch,
        SceneEntity.kIsCurrent: false,
      });
      if (oldUpdate == null) {
        logger?.w("Cannot found the old scene");
      }
      // Update the new one
      final newUpdate = await store.record(newSceneID).update(tx, {
        SceneEntity.kLastAccessTime: this.clock.now().millisecondsSinceEpoch,
        SceneEntity.kIsCurrent: true,
      });
      if (newUpdate == null) {
        throw InvalidOperationException(message: 'Failed to update new scene');
      }
      // Load the new one
      final newCurrentRecord = await store.record(newSceneID).get(tx);
      if (newCurrentRecord == null) {
        throw KeyNotFoundException(message: 'Failed to found current scene ID `$newSceneID`');
      }
      final fromScene = _current;
      final toScene = await _restoreSceneImagePath(tx, SceneEntity.fromMap(newSceneID, newCurrentRecord));
      _current = toScene;
      _globalEventBus.fire(CurrentSceneChangedEvent(fromScene, toScene));
      return toScene;
    });
  }

  @override
  Future<SceneEntity> create({required String name, required String notes, String? imagePath}) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);
    return await _db.transaction((tx) async {
      final preparedImage = await _prepareSceneImage(imagePath);
      final scene = SceneEntity(
        id: BaseEntity.generateID(),
        name: name,
        isCurrent: false,
        lastAccessTime: this.clock.now(),
        notes: notes,
        imageID: preparedImage.imageID,
        imagePath: preparedImage.imagePath,
      );
      await store.record(scene.id).put(tx, scene.toMap());
      _globalEventBus.fire(SceneCreatedEvent(scene));
      return scene;
    });
  }

  @override
  Future<SceneEntity> update({
    required String id,
    required String name,
    required String notes,
    String? imagePath,
    Transaction? tx,
  }) async {
    if (tx == null) {
      return await _db.transaction((tx) => update(id: id, name: name, notes: notes, imagePath: imagePath, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.scenes);
      final existingMap = (await store.record(id).get(tx))!;
      final existingScene = SceneEntity.fromMap(id, existingMap);
      final preparedImage = await _prepareSceneImage(
        imagePath,
        existingImageID: existingScene.imageID,
        existingImagePath: existingScene.imagePath,
      );
      final record = await store.record(id).update(tx, {
        SceneEntity.kNameField: name,
        SceneEntity.kNotesFieldName: notes,
        SceneEntity.kImageIDFieldName: preparedImage.imageID,
        SceneEntity.kImagePathFieldName: preparedImage.imagePath,
      });
      if (record == null) {
        throw InvalidOperationException(message: 'Failed to update record');
      }
      final scene = SceneEntity.fromMap(id, record);
      // if this is the current scene, keep _current in sync so callers using
      // the getter see the latest values without requiring a reload.
      if (_current.id == id) {
        _current = scene;
      }
      _globalEventBus.fire(SceneUpdatedEvent(scene));
      return scene;
    }
  }

  @override
  Future<void> delete(String id, {Transaction? tx}) async {
    if (tx == null) {
      await _db.transaction((tx) => delete(id, tx: tx));
    } else {
      logger?.i('Begin deleting the scene id=`$id`');

      // Check if this is the last scene
      final sceneStore = stringMapStoreFactory.store(StoreNames.scenes);
      final totalScenesCount = await sceneStore.count(tx);
      if (totalScenesCount <= 1) {
        throw CannotDeleteLastSceneException();
      }

      // Check if scene has devices or groups
      final deviceStore = stringMapStoreFactory.store(StoreNames.devices);
      final deviceCount = await deviceStore.count(tx, filter: Filter.equals(DeviceEntity.kSceneIDFieldName, id));

      final groupStore = stringMapStoreFactory.store(StoreNames.groups);
      final groupCount = await groupStore.count(tx, filter: Filter.equals(DeviceGroupEntity.kSceneIDFieldName, id));

      if (deviceCount > 0 || groupCount > 0) {
        throw SceneContainsDevicesOrGroupsException();
      }
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

  @override
  Future<SceneEntity> getLastAccessed({CancellationToken? cancelToken}) async {
    assert(isInitialized);
    return await _db.transaction((tx) async {
      final store = stringMapStoreFactory.store(StoreNames.scenes);
      final records = await store.find(tx);

      if (records.isEmpty) {
        throw KeyNotFoundException(message: 'No scenes found');
      }

      SceneEntity? lastAccessed;
      int lastAccessEpoch = -1;

      for (final record in records) {
        if (cancelToken?.isCancelled == true) {
          throw Exception('Operation cancelled');
        }
        final scene = await _restoreSceneImagePath(tx, SceneEntity.fromMap(record.key, record.value));
        final accessEpoch = scene.lastAccessTime.millisecondsSinceEpoch;
        if (accessEpoch > lastAccessEpoch) {
          lastAccessEpoch = accessEpoch;
          lastAccessed = scene;
        }
      }

      if (lastAccessed == null) {
        throw KeyNotFoundException(message: 'No last accessed scene found');
      }
      return lastAccessed;
    });
  }
}
