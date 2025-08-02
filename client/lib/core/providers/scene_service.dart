import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';

import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/scene_manager.dart';

import 'scene_state.dart';

// External providers that need to be provided by the application
final sceneManagerProvider = Provider<ISceneManager>((ref) {
  throw UnimplementedError('SceneManager must be provided by context');
});

final eventBusProvider = Provider<EventBus>((ref) {
  throw UnimplementedError('EventBus must be provided by context');
});

final loggerProvider = Provider<Logger?>((ref) {
  throw UnimplementedError('Logger must be provided by context');
});

/// Scene Service - Riverpod style scene management service
/// Acts as a bridge to ISceneManager while providing Riverpod state management
class SceneService extends StateNotifier<SceneState> {
  final ISceneManager _sceneManager;
  final Logger? _logger;
  final EventBus _eventBus;

  SceneService({required ISceneManager sceneManager, required EventBus eventBus, Logger? logger})
    : _sceneManager = sceneManager,
      _logger = logger,
      _eventBus = eventBus,
      super(const SceneState()) {
    // Listen to scene events to update state
    _setupEventListeners();
  }

  /// Initialize service
  /// Note: In Riverpod, explicit initialization is usually not needed
  /// but this is kept for compatibility
  Future<void> initialize({IGroupManager? groupManager, IDeviceManager? deviceManager}) async {
    if (state.isInitialized) return;

    state = state.copyWith(isLoading: true);

    try {
      await _sceneManager.initialize(groupManager!, deviceManager!);
      await _loadScenesFromManager();

      state = state.copyWith(isInitialized: true, isLoading: false, error: null);

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
      final newScene = await _sceneManager.create(name: name, notes: notes, imagePath: imagePath);
      await _loadScenesFromManager();

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
      final updatedScene = await _sceneManager.update(id: id, name: name, notes: notes, imagePath: imagePath);
      await _loadScenesFromManager();

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
      await _sceneManager.delete(id);
      await _loadScenesFromManager();

      _logger?.i('Scene deleted: $id');
    } catch (e, stackTrace) {
      _logger?.e('Failed to delete scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to delete scene: $e');
      rethrow;
    }
  }

  /// Switch to current scene
  Future<void> switchToScene(String sceneId) async {
    if (state.isLoading) return;

    // If already current scene, return directly
    if (state.currentScene?.id == sceneId) return;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _sceneManager.changeCurrent(sceneId);
      await _loadScenesFromManager();

      _logger?.i('Switched to scene: $sceneId');
    } catch (e, stackTrace) {
      _logger?.e('Failed to switch scene', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to switch scene: $e');
      rethrow;
    }
  }

  /// Get device statistics for scene
  Future<DeviceStatistics> getDeviceStatistics(String sceneId) async {
    try {
      return await _sceneManager.getDeviceStatistics(sceneId);
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
      await _loadScenesFromManager();
      _logger?.i('Scene data refreshed');
    } catch (e, stackTrace) {
      _logger?.e('Failed to refresh scene data', error: e, stackTrace: stackTrace);
      state = state.copyWith(isLoading: false, error: 'Failed to refresh: $e');
    }
  }

  // Private methods

  void _setupEventListeners() {
    // Listen to scene events from ISceneManager to update our state
    _eventBus.on<SceneCreatedEvent>().listen((_) => _loadScenesFromManager());
    _eventBus.on<SceneUpdatedEvent>().listen((_) => _loadScenesFromManager());
    _eventBus.on<SceneDeletedEvent>().listen((_) => _loadScenesFromManager());
    _eventBus.on<CurrentSceneChangedEvent>().listen((_) => _loadScenesFromManager());
  }

  Future<void> _loadScenesFromManager() async {
    try {
      final allScenes = await _sceneManager.all();
      final currentScene = _sceneManager.current;

      state = state.copyWith(scenes: allScenes, currentScene: currentScene, isLoading: false, error: null);
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'Failed to load scenes: $e');
    }
  }
}

/// Scene Service Provider
final sceneServiceProvider = StateNotifierProvider<SceneService, SceneState>((ref) {
  final sceneManager = ref.watch(sceneManagerProvider);
  final logger = ref.watch(loggerProvider);
  final eventBus = ref.watch(eventBusProvider);

  return SceneService(sceneManager: sceneManager, logger: logger, eventBus: eventBus);
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
