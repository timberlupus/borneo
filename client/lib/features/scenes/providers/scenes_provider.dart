import 'dart:async';

import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Scene Summary State
class SceneSummaryState {
  final SceneEntity scene;
  final int totalDeviceCount;
  final int activeDeviceCount;
  final bool isSelected;

  const SceneSummaryState({
    required this.scene,
    required this.totalDeviceCount,
    required this.activeDeviceCount,
    required this.isSelected,
  });

  String get id => scene.id;
  String get name => scene.name;

  SceneSummaryState copyWith({SceneEntity? scene, int? totalDeviceCount, int? activeDeviceCount, bool? isSelected}) {
    return SceneSummaryState(
      scene: scene ?? this.scene,
      totalDeviceCount: totalDeviceCount ?? this.totalDeviceCount,
      activeDeviceCount: activeDeviceCount ?? this.activeDeviceCount,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

/// Scene Summary Notifier
class SceneSummaryNotifier extends StateNotifier<SceneSummaryState> {
  final ISceneManager _sceneManager;
  final DeviceManager _deviceManager;
  final EventBus _eventBus;

  late final StreamSubscription<CurrentSceneChangedEvent> _currentSceneChangedSub;
  late final StreamSubscription<SceneUpdatedEvent> _sceneUpdatedSub;
  late final StreamSubscription<DeviceBoundEvent> _deviceBoundSub;
  late final StreamSubscription<DeviceRemovedEvent> _deviceRemovedSub;
  late final StreamSubscription<DeviceManagerReadyEvent> _deviceManagerReadySub;

  SceneSummaryNotifier(
    this._sceneManager,
    this._deviceManager,
    this._eventBus,
    SceneEntity scene,
    DeviceStatistics deviceStats,
  ) : super(
        SceneSummaryState(
          scene: scene,
          totalDeviceCount: deviceStats.totalDeviceCount,
          activeDeviceCount: deviceStats.activeDeviceCount,
          isSelected: scene.id == _sceneManager.current.id,
        ),
      ) {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _currentSceneChangedSub = _eventBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged);
    _sceneUpdatedSub = _eventBus.on<SceneUpdatedEvent>().listen(_onSceneUpdated);
    _deviceBoundSub = _deviceManager.allDeviceEvents.on<DeviceBoundEvent>().listen(_onDeviceBound);
    _deviceRemovedSub = _deviceManager.allDeviceEvents.on<DeviceRemovedEvent>().listen(_onDeviceRemoved);
    _deviceManagerReadySub = _eventBus.on<DeviceManagerReadyEvent>().listen(_onDeviceManagerReady);
  }

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    final isSelected = event.to.id == state.scene.id;
    if (isSelected != state.isSelected) {
      state = state.copyWith(isSelected: isSelected);
    }

    if (event.from.id == state.scene.id || event.to.id == state.scene.id) {
      _updateDeviceStatistics();
    }
  }

  void _onSceneUpdated(SceneUpdatedEvent event) {
    if (event.scene.id == state.scene.id) {
      state = state.copyWith(scene: event.scene);
    }
  }

  void _onDeviceBound(DeviceBoundEvent event) {
    _updateDeviceStatistics();
  }

  void _onDeviceRemoved(DeviceRemovedEvent event) {
    _updateDeviceStatistics();
  }

  void _onDeviceManagerReady(final DeviceManagerReadyEvent _) {
    _updateDeviceStatistics();
  }

  Future<void> _updateDeviceStatistics() async {
    try {
      final deviceStats = await _sceneManager.getDeviceStatistics(state.scene.id);
      state = state.copyWith(
        totalDeviceCount: deviceStats.totalDeviceCount,
        activeDeviceCount: deviceStats.activeDeviceCount,
      );
    } catch (e) {
      // Handle error silently or log it
    }
  }

  @override
  void dispose() {
    _currentSceneChangedSub.cancel();
    _sceneUpdatedSub.cancel();
    _deviceBoundSub.cancel();
    _deviceRemovedSub.cancel();
    _deviceManagerReadySub.cancel();
    super.dispose();
  }
}

/// Scenes State
class ScenesState {
  final List<SceneSummaryState> scenes;
  final bool isLoading;
  final String? error;

  const ScenesState({this.scenes = const [], this.isLoading = false, this.error});

  ScenesState copyWith({List<SceneSummaryState>? scenes, bool? isLoading, String? error}) {
    return ScenesState(
      scenes: scenes ?? this.scenes,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Scenes Notifier
class ScenesNotifier extends StateNotifier<ScenesState> {
  final ISceneManager _sceneManager;
  final EventBus _eventBus;

  late final StreamSubscription<CurrentSceneChangedEvent> _currentSceneChangedSub;
  late final StreamSubscription<SceneCreatedEvent> _sceneCreatedSub;
  late final StreamSubscription<SceneDeletedEvent> _sceneDeletedSub;
  late final StreamSubscription<SceneUpdatedEvent> _sceneUpdatedSub;
  late final StreamSubscription<DeviceManagerReadyEvent> _deviceManagerReadySub;

  final Map<String, SceneSummaryNotifier> _sceneNotifiers = {};

  ScenesNotifier(this._sceneManager, DeviceManager deviceManager, this._eventBus, Logger? logger)
    : super(const ScenesState()) {
    // deviceManager and logger are passed for potential future use
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _currentSceneChangedSub = _eventBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged);
    _sceneCreatedSub = _eventBus.on<SceneCreatedEvent>().listen(_onSceneCreated);
    _sceneDeletedSub = _eventBus.on<SceneDeletedEvent>().listen(_onSceneDeleted);
    _sceneUpdatedSub = _eventBus.on<SceneUpdatedEvent>().listen(_onSceneUpdated);
    _deviceManagerReadySub = _eventBus.on<DeviceManagerReadyEvent>().listen(_onDeviceManagerReady);
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _reload();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _reload() async {
    // Dispose existing notifiers
    for (final notifier in _sceneNotifiers.values) {
      notifier.dispose();
    }
    _sceneNotifiers.clear();

    final scenes = await _sceneManager.all();
    final sceneStates = <SceneSummaryState>[];

    for (final scene in scenes) {
      final deviceStats = await _sceneManager.getDeviceStatistics(scene.id);
      final sceneState = SceneSummaryState(
        scene: scene,
        totalDeviceCount: deviceStats.totalDeviceCount,
        activeDeviceCount: deviceStats.activeDeviceCount,
        isSelected: scene.id == _sceneManager.current.id,
      );
      sceneStates.add(sceneState);
    }

    // Sort scenes
    sceneStates.sort((a, b) {
      if (a.isSelected && !b.isSelected) {
        return -1;
      } else if (!a.isSelected && b.isSelected) {
        return 1;
      } else {
        return b.scene.lastAccessTime.compareTo(a.scene.lastAccessTime);
      }
    });

    state = state.copyWith(scenes: sceneStates);
  }

  Future<void> switchCurrentScene(String newSceneID) async {
    if (newSceneID == _sceneManager.current.id || state.isLoading) {
      return;
    }

    state = state.copyWith(isLoading: true);
    try {
      await _sceneManager.changeCurrent(newSceneID);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    // Update scenes to reflect the new current scene
    final updatedScenes = state.scenes.map((scene) {
      return scene.copyWith(isSelected: scene.id == event.to.id);
    }).toList();

    state = state.copyWith(scenes: updatedScenes);
  }

  void _onSceneCreated(SceneCreatedEvent event) {
    if (!state.isLoading) {
      _reload();
    }
  }

  void _onSceneDeleted(SceneDeletedEvent event) {
    if (!state.isLoading) {
      _reload();
    }
  }

  void _onSceneUpdated(SceneUpdatedEvent event) {
    final updatedScenes = state.scenes.map((scene) {
      if (scene.id == event.scene.id) {
        return scene.copyWith(scene: event.scene);
      }
      return scene;
    }).toList();

    state = state.copyWith(scenes: updatedScenes);
  }

  void _onDeviceManagerReady(final DeviceManagerReadyEvent _) {
    if (!state.isLoading) {
      _reload();
    }
  }

  @override
  void dispose() {
    _currentSceneChangedSub.cancel();
    _sceneCreatedSub.cancel();
    _sceneDeletedSub.cancel();
    _sceneUpdatedSub.cancel();
    _deviceManagerReadySub.cancel();

    for (final notifier in _sceneNotifiers.values) {
      notifier.dispose();
    }
    _sceneNotifiers.clear();

    super.dispose();
  }
}

// Core providers that need to be provided elsewhere
final sceneManagerProvider = Provider<ISceneManager>((ref) {
  throw UnimplementedError('SceneManager must be provided by context');
});

final deviceManagerProvider = Provider<DeviceManager>((ref) {
  throw UnimplementedError('DeviceManager must be provided by context');
});

final eventBusProvider = Provider<EventBus>((ref) {
  throw UnimplementedError('EventBus must be provided by context');
});

final loggerProvider = Provider<Logger?>((ref) {
  throw UnimplementedError('Logger must be provided by context');
});

/// Scenes Provider
final scenesProvider = StateNotifierProvider<ScenesNotifier, ScenesState>((ref) {
  final sceneManager = ref.watch(sceneManagerProvider);
  final deviceManager = ref.watch(deviceManagerProvider);
  final eventBus = ref.watch(eventBusProvider);
  final logger = ref.watch(loggerProvider);

  return ScenesNotifier(sceneManager, deviceManager, eventBus, logger);
}, dependencies: [sceneManagerProvider, deviceManagerProvider, eventBusProvider, loggerProvider]);

/// Individual Scene Provider (not used directly - scenes are managed through scenesProvider)
final sceneSummaryProvider = StateNotifierProvider.family<SceneSummaryNotifier, SceneSummaryState, String>((
  ref,
  sceneId,
) {
  // This provider would need to be initialized with the scene and device stats
  // Currently not used - scenes are managed through scenesProvider
  throw UnimplementedError('Use scenesProvider instead for managing all scenes');
}, dependencies: [sceneManagerProvider, deviceManagerProvider, eventBusProvider]);
