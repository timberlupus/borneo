import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';

import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/services/blob_manager.dart';
import 'package:borneo_app/core/services/store_names.dart';
import 'package:borneo_app/core/services/devices/i_device_manager.dart';
import 'package:borneo_app/core/services/i_group_manager.dart';
import 'package:borneo_app/shared/models/base_entity.dart';
import 'package:borneo_app/app/assets.dart';

import 'core_providers.dart';
import 'scene_state.dart';

/// Scene Service - Riverpod style scene management service
class SceneService extends StateNotifier<SceneState> {
  final Database _db;
  final Logger? _logger;
  final EventBus _eventBus;
  final IBlobManager _blobManager;

  // These dependencies may need special handling before full migration
  IGroupManager? _groupManager;
  IDeviceManager? _deviceManager;

  SceneService({required Database db, required EventBus eventBus, required IBlobManager blobManager, Logger? logger})
    : _db = db,
      _logger = logger,
      _eventBus = eventBus,
      _blobManager = blobManager,
      super(const SceneState());

  /// Initialize service
  /// Note: In Riverpod, explicit initialization is usually not needed
  /// but this is kept for compatibility
  Future<void> initialize({IGroupManager? groupManager, IDeviceManager? deviceManager}) async {
    if (state.isInitialized) return;

    _groupManager = groupManager;
    _deviceManager = deviceManager;

    state = state.copyWith(isLoading: true);

    try {
      await _db.transaction((tx) async {
        await _ensureDefaultScenesExist(tx);
        final currentScene = await _fetchCurrentScene(tx);
        final allScenes = await _fetchAllScenes(tx);

        state = state.copyWith(
          scenes: allScenes,
          currentScene: currentScene,
          isInitialized: true,
          isLoading: false,
          error: null,
        );
      });

      _logger?.i('SceneService initialized successfully');
    } catch (e, stackTrace) {
      _logger?.e('Failed to initialize SceneService', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to initialize: $e');
      rethrow;
    }
  }

  /// Create new scene
  Future<void> createScene({required String name, required String notes, String? imagePath}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      String? imageID;
      String? finalImagePath;

      // Handle image
      if (imagePath != null) {
        // Simplified handling here, might need to copy image to app directory in real implementation
        finalImagePath = imagePath;
      }

      final newScene = SceneEntity(
        id: BaseEntity.generateID(),
        name: name,
        notes: notes,
        imagePath: finalImagePath,
        imageID: imageID,
        isCurrent: false,
        lastAccessTime: DateTime.now(),
      );

      await _db.transaction((tx) async {
        final store = stringMapStoreFactory.store(StoreNames.scenes);
        await store.record(newScene.id).put(tx, newScene.toMap());
      });

      // Update state
      final updatedScenes = [...state.scenes, newScene];
      state = state.copyWith(scenes: updatedScenes, isLoading: false);
      // Fire event
      _eventBus.fire(SceneCreatedEvent(newScene));

      _logger?.i('Scene created: ${newScene.name}');
    } catch (e, stackTrace) {
      _logger?.e('Failed to create scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to create scene: $e');
      rethrow;
    }
  }

  /// Update scene
  Future<void> updateScene({required String id, required String name, required String notes, String? imagePath}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final sceneIndex = state.scenes.indexWhere((s) => s.id == id);
      if (sceneIndex == -1) {
        throw Exception('Scene not found');
      }

      final existingScene = state.scenes[sceneIndex];
      final updatedScene = existingScene.copyWith(name: name, notes: notes, imagePath: imagePath);

      await _db.transaction((tx) async {
        final store = stringMapStoreFactory.store(StoreNames.scenes);
        await store.record(id).put(tx, updatedScene.toMap());
      });

      // Update state
      final updatedScenes = [...state.scenes];
      updatedScenes[sceneIndex] = updatedScene;

      SceneEntity? updatedCurrentScene = state.currentScene;
      if (state.currentScene?.id == id) {
        updatedCurrentScene = updatedScene;
      }

      state = state.copyWith(scenes: updatedScenes, currentScene: updatedCurrentScene, isLoading: false);
      // Fire event
      _eventBus.fire(SceneUpdatedEvent(updatedScene));

      _logger?.i('Scene updated: ${updatedScene.name}');
    } catch (e, stackTrace) {
      _logger?.e('Failed to update scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to update scene: $e');
      rethrow;
    }
  }

  /// Delete scene
  Future<void> deleteScene(String id) async {
    if (state.isLoading) return;

    // Cannot delete current scene
    if (state.currentScene?.id == id) {
      state = state.copyWith(error: 'Cannot delete current scene');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final sceneToDelete = state.scenes.firstWhere(
        (s) => s.id == id,
        orElse: () => throw Exception('Scene not found'),
      );

      await _db.transaction((tx) async {
        final store = stringMapStoreFactory.store(StoreNames.scenes);
        await store.record(id).delete(tx);
      });

      // Update state
      final updatedScenes = state.scenes.where((s) => s.id != id).toList();
      state = state.copyWith(scenes: updatedScenes, isLoading: false);
      // Fire event
      _eventBus.fire(SceneDeletedEvent(id));

      _logger?.i('Scene deleted: ${sceneToDelete.name}');
    } catch (e, stackTrace) {
      _logger?.e('Failed to delete scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to delete scene: $e');
      rethrow;
    }
  }

  /// Switch to current scene
  Future<void> switchToScene(String sceneId) async {
    if (state.isLoading) return;

    final scene = state.scenes.firstWhere((s) => s.id == sceneId, orElse: () => throw Exception('Scene not found'));

    // If already current scene, return directly
    if (state.currentScene?.id == sceneId) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _db.transaction((tx) async {
        final store = stringMapStoreFactory.store(StoreNames.scenes);

        // Update old current scene
        if (state.currentScene != null) {
          final oldCurrent = state.currentScene!.copyWith(isCurrent: false);
          await store.record(oldCurrent.id).put(tx, oldCurrent.toMap());
        }

        // Set new current scene
        final newCurrent = scene.copyWith(isCurrent: true, lastAccessTime: DateTime.now());
        await store.record(newCurrent.id).put(tx, newCurrent.toMap());
      });

      // Update state
      final updatedScenes = state.scenes.map((s) {
        if (s.id == sceneId) {
          return s.copyWith(isCurrent: true, lastAccessTime: DateTime.now());
        } else if (s.isCurrent) {
          return s.copyWith(isCurrent: false);
        }
        return s;
      }).toList();

      final newCurrentScene = updatedScenes.firstWhere((s) => s.id == sceneId);
      final oldCurrentScene = state.currentScene;

      state = state.copyWith(scenes: updatedScenes, currentScene: newCurrentScene, isLoading: false);
      // Fire event
      if (oldCurrentScene != null) {
        _eventBus.fire(CurrentSceneChangedEvent(oldCurrentScene, newCurrentScene));
      }

      _logger?.i('Switched to scene: ${newCurrentScene.name}');
    } catch (e, stackTrace) {
      _logger?.e('Failed to switch scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to switch scene: $e');
      rethrow;
    }
  }

  /// Get device statistics for scene
  Future<DeviceStatistics> getDeviceStatistics(String sceneId) async {
    try {
      // This depends on DeviceManager, may need special handling before full migration
      if (_deviceManager != null && _groupManager != null) {
        // Call original logic
        // return await _originalSceneManager.getDeviceStatistics(sceneId);
      }
      // Temporarily return empty statistics
      return const DeviceStatistics(0, 0); // totalDeviceCount, activeDeviceCount
    } catch (e, stackTrace) {
      _logger?.e('Failed to get device statistics', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Refresh all scene data
  Future<void> refresh() async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      final allScenes = await _fetchAllScenes();
      final currentScene = allScenes.firstWhere(
        (s) => s.isCurrent,
        orElse: () => allScenes.isNotEmpty ? allScenes.first : throw Exception('No scenes found'),
      );

      state = state.copyWith(scenes: allScenes, currentScene: currentScene, isLoading: false);

      _logger?.i('Scene data refreshed');
    } catch (e, stackTrace) {
      _logger?.e('Failed to refresh scene data', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to refresh: $e');
    }
  }

  // Private methods

  Future<void> _ensureDefaultScenesExist(Transaction tx) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);

    if (await store.count(tx) <= 0) {
      try {
        // Create default home scene
        final homeImageID = await _blobManager.create(await rootBundle.load(AssetsPath.kHomeSceneImagePath));

        final homeScene = SceneEntity.newDefault().copyWith(
          name: 'My Home', // Simplified, not using internationalization
          imageID: homeImageID,
          imagePath: _blobManager.getPath(homeImageID),
        );
        await store.record(homeScene.id).put(tx, homeScene.toMap());

        // Create office scene
        final officeImageID = await _blobManager.create(await rootBundle.load(AssetsPath.kOfficeSceneImagePath));
        final officeScene = SceneEntity(
          id: BaseEntity.generateID(),
          name: 'My Office',
          notes: '',
          isCurrent: false,
          lastAccessTime: DateTime.now(),
          imageID: officeImageID,
          imagePath: _blobManager.getPath(officeImageID),
        );
        await store.record(officeScene.id).put(tx, officeScene.toMap());

        _logger?.i('Default scenes created');
      } catch (e, stackTrace) {
        _logger?.w('Failed to create default scenes', error: e, stackTrace: stackTrace);
        // Create simple default scene
        final homeScene = SceneEntity.newDefault().copyWith(name: 'Default Scene');
        await store.record(homeScene.id).put(tx, homeScene.toMap());
      }
    }
  }

  Future<SceneEntity> _fetchCurrentScene([Transaction? tx]) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);
    final finder = Finder(limit: 1, filter: Filter.equals(SceneEntity.kIsCurrent, true));

    final operation = tx != null
        ? store.findFirst(tx, finder: finder)
        : _db.transaction((tx) => store.findFirst(tx, finder: finder));

    final currentRecord = await operation;

    if (currentRecord == null) {
      throw Exception('No current scene found');
    }

    return SceneEntity.fromMap(currentRecord.key, currentRecord.value);
  }

  Future<List<SceneEntity>> _fetchAllScenes([Transaction? tx]) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);

    final operation = tx != null ? store.find(tx) : _db.transaction((tx) => store.find(tx));

    final records = await operation;

    return records.map((record) => SceneEntity.fromMap(record.key, record.value)).toList();
  }
}

/// Scene Service Provider
final sceneServiceProvider = StateNotifierProvider<SceneService, SceneState>((ref) {
  final db = ref.watch(databaseProvider);
  final logger = ref.watch(loggerProvider);
  final eventBus = ref.watch(eventBusProvider);
  final blobManager = ref.watch(blobManagerProvider);

  return SceneService(db: db, logger: logger, eventBus: eventBus, blobManager: blobManager);
});

/// Convenience Provider - current scene
final currentSceneProvider = Provider<SceneEntity?>((ref) {
  return ref.watch(sceneServiceProvider).currentScene;
});

/// Convenience Provider - all scenes
final allScenesProvider = Provider<List<SceneEntity>>((ref) {
  return ref.watch(sceneServiceProvider).scenes;
});

/// Convenience Provider - scene loading status
final sceneLoadingProvider = Provider<bool>((ref) {
  return ref.watch(sceneServiceProvider).isLoading;
});

/// Convenience Provider - scene error message
final sceneErrorProvider = Provider<String?>((ref) {
  return ref.watch(sceneServiceProvider).error;
});

/// Provider to get scene by ID
final sceneByIdProvider = Provider.family<SceneEntity?, String>((ref, sceneId) {
  final scenes = ref.watch(allScenesProvider);
  try {
    return scenes.firstWhere((scene) => scene.id == sceneId);
  } catch (e) {
    return null;
  }
});

/// Scene device statistics Provider
final sceneDeviceStatisticsProvider = FutureProvider.family<DeviceStatistics, String>((ref, sceneId) async {
  final sceneService = ref.read(sceneServiceProvider.notifier);
  return await sceneService.getDeviceStatistics(sceneId);
});
