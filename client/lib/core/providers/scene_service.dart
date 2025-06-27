import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/services.dart';

import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:borneo_app/core/services/blob_manager.dart';
import 'package:borneo_app/core/services/store_names.dart';
import 'package:borneo_app/core/services/devices/i_device_manager.dart';
import 'package:borneo_app/core/services/i_group_manager.dart';
import 'package:borneo_app/shared/models/base_entity.dart';
import 'package:borneo_app/app/assets.dart';

import 'core_providers.dart';
import 'scene_state.dart';

/// Scene Service - Riverpod 风格的场景管理服务
class SceneService extends StateNotifier<SceneState> {
  final Database _db;
  final Logger? _logger;
  final EventBus _eventBus;
  final IBlobManager _blobManager;

  // 在完全迁移前，这些依赖可能需要特殊处理
  IGroupManager? _groupManager;
  IDeviceManager? _deviceManager;

  SceneService({required Database db, required EventBus eventBus, required IBlobManager blobManager, Logger? logger})
    : _db = db,
      _logger = logger,
      _eventBus = eventBus,
      _blobManager = blobManager,
      super(const SceneState());

  /// 初始化服务
  /// 注意：在 Riverpod 中，通常不需要显式调用初始化
  /// 但这里保留了兼容性
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

  /// 创建新场景
  Future<void> createScene({required String name, required String notes, String? imagePath}) async {
    if (state.isLoading) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      String? imageID;
      String? finalImagePath;

      // 处理图片
      if (imagePath != null) {
        // 这里简化处理，实际可能需要复制图片到应用目录
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

      // 更新状态
      final updatedScenes = [...state.scenes, newScene];
      state = state.copyWith(scenes: updatedScenes, isLoading: false);
      // 发送事件（简化版本，不使用具体的事件类）
      _eventBus.fire('scene_created');

      _logger?.i('Scene created: ${newScene.name}');
    } catch (e, stackTrace) {
      _logger?.e('Failed to create scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to create scene: $e');
      rethrow;
    }
  }

  /// 更新场景
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

      // 更新状态
      final updatedScenes = [...state.scenes];
      updatedScenes[sceneIndex] = updatedScene;

      SceneEntity? updatedCurrentScene = state.currentScene;
      if (state.currentScene?.id == id) {
        updatedCurrentScene = updatedScene;
      }

      state = state.copyWith(scenes: updatedScenes, currentScene: updatedCurrentScene, isLoading: false);
      // 发送事件（简化版本）
      _eventBus.fire('scene_updated');

      _logger?.i('Scene updated: ${updatedScene.name}');
    } catch (e, stackTrace) {
      _logger?.e('Failed to update scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to update scene: $e');
      rethrow;
    }
  }

  /// 删除场景
  Future<void> deleteScene(String id) async {
    if (state.isLoading) return;

    // 不允许删除当前场景
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

      // 更新状态
      final updatedScenes = state.scenes.where((s) => s.id != id).toList();
      state = state.copyWith(scenes: updatedScenes, isLoading: false);
      // 发送事件（简化版本）
      _eventBus.fire('scene_deleted');

      _logger?.i('Scene deleted: ${sceneToDelete.name}');
    } catch (e, stackTrace) {
      _logger?.e('Failed to delete scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to delete scene: $e');
      rethrow;
    }
  }

  /// 切换当前场景
  Future<void> switchToScene(String sceneId) async {
    if (state.isLoading) return;

    final scene = state.scenes.firstWhere((s) => s.id == sceneId, orElse: () => throw Exception('Scene not found'));

    // 如果已经是当前场景，直接返回
    if (state.currentScene?.id == sceneId) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _db.transaction((tx) async {
        final store = stringMapStoreFactory.store(StoreNames.scenes);

        // 更新旧的当前场景
        if (state.currentScene != null) {
          final oldCurrent = state.currentScene!.copyWith(isCurrent: false);
          await store.record(oldCurrent.id).put(tx, oldCurrent.toMap());
        }

        // 设置新的当前场景
        final newCurrent = scene.copyWith(isCurrent: true, lastAccessTime: DateTime.now());
        await store.record(newCurrent.id).put(tx, newCurrent.toMap());
      });

      // 更新状态
      final updatedScenes = state.scenes.map((s) {
        if (s.id == sceneId) {
          return s.copyWith(isCurrent: true, lastAccessTime: DateTime.now());
        } else if (s.isCurrent) {
          return s.copyWith(isCurrent: false);
        }
        return s;
      }).toList();

      final newCurrentScene = updatedScenes.firstWhere((s) => s.id == sceneId);

      state = state.copyWith(scenes: updatedScenes, currentScene: newCurrentScene, isLoading: false);
      // 发送事件（简化版本）
      _eventBus.fire('current_scene_changed');

      _logger?.i('Switched to scene: ${newCurrentScene.name}');
    } catch (e, stackTrace) {
      _logger?.e('Failed to switch scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to switch scene: $e');
      rethrow;
    }
  }

  /// 获取场景的设备统计信息
  Future<DeviceStatistics> getDeviceStatistics(String sceneId) async {
    try {
      // 这里需要依赖 DeviceManager，在完全迁移前可能需要特殊处理
      if (_deviceManager != null && _groupManager != null) {
        // 调用原有的逻辑
        // return await _originalSceneManager.getDeviceStatistics(sceneId);
      }
      // 临时返回空统计信息
      return const DeviceStatistics(0, 0); // totalDeviceCount, activeDeviceCount
    } catch (e, stackTrace) {
      _logger?.e('Failed to get device statistics', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// 刷新所有场景数据
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

  // 私有方法

  Future<void> _ensureDefaultScenesExist(Transaction tx) async {
    final store = stringMapStoreFactory.store(StoreNames.scenes);

    if (await store.count(tx) <= 0) {
      try {
        // 创建默认的家庭场景
        final homeImageID = await _blobManager.create(await rootBundle.load(AssetsPath.kHomeSceneImagePath));

        final homeScene = SceneEntity.newDefault().copyWith(
          name: 'My Home', // 简化，不使用国际化
          imageID: homeImageID,
          imagePath: _blobManager.getPath(homeImageID),
        );
        await store.record(homeScene.id).put(tx, homeScene.toMap());

        // 创建办公室场景
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
        // 创建简单的默认场景
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

/// 便捷的 Provider - 当前场景
final currentSceneProvider = Provider<SceneEntity?>((ref) {
  return ref.watch(sceneServiceProvider).currentScene;
});

/// 便捷的 Provider - 所有场景
final allScenesProvider = Provider<List<SceneEntity>>((ref) {
  return ref.watch(sceneServiceProvider).scenes;
});

/// 便捷的 Provider - 场景是否正在加载
final sceneLoadingProvider = Provider<bool>((ref) {
  return ref.watch(sceneServiceProvider).isLoading;
});

/// 便捷的 Provider - 场景错误信息
final sceneErrorProvider = Provider<String?>((ref) {
  return ref.watch(sceneServiceProvider).error;
});

/// 按 ID 获取场景的 Provider
final sceneByIdProvider = Provider.family<SceneEntity?, String>((ref, sceneId) {
  final scenes = ref.watch(allScenesProvider);
  try {
    return scenes.firstWhere((scene) => scene.id == sceneId);
  } catch (e) {
    return null;
  }
});

/// 场景设备统计 Provider
final sceneDeviceStatisticsProvider = FutureProvider.family<DeviceStatistics, String>((ref, sceneId) async {
  final sceneService = ref.read(sceneServiceProvider.notifier);
  return await sceneService.getDeviceStatistics(sceneId);
});
