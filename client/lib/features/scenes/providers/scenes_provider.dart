import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/events.dart';
// events fired by kernel/device manager
import 'package:borneo_kernel_abstractions/events.dart';
import '../../devices/models/events.dart';
import '../view_models/scenes_view_model.dart';
import '../../../core/providers.dart';
import '../../../core/services/scene_manager.dart';

// ---------------------------------------------------------------------------
// State
// ---------------------------------------------------------------------------

class ScenesState {
  final List<SceneSummaryModel> scenes;
  final bool isLoading;
  final String? error;

  /// When non-null the view model is actively switching to the scene with this
  /// ID.  Used by UI code to give per-card feedback while a change is in
  /// progress.
  final String? switchingSceneId;

  const ScenesState({required this.scenes, this.isLoading = false, this.error, this.switchingSceneId});

  ScenesState copyWith({
    List<SceneSummaryModel>? scenes,
    bool? isLoading,
    Object? error = _sentinel,
    Object? switchingSceneId = _sentinel,
  }) {
    return ScenesState(
      scenes: scenes ?? this.scenes,
      isLoading: isLoading ?? this.isLoading,
      error: error == _sentinel ? this.error : (error as String?),
      switchingSceneId: switchingSceneId == _sentinel ? this.switchingSceneId : (switchingSceneId as String?),
    );
  }
}

const _sentinel = Object();

/// Convenience provider that exposes the scenes-loading flag with a default of
/// `false`.  This lets widgets such as [ChoreList] watch the scenes loading
/// state without crashing when they are used outside of a
/// [ProvideScenesViewModel] scope (e.g. isolated widget tests).
///
/// [ProvideScenesViewModel] must override this provider so it reflects the
/// real [scenesProvider] state.
final scenesIsLoadingProvider = Provider<bool>((ref) => false, name: 'scenesIsLoadingProvider');

// ---------------------------------------------------------------------------
// Provider
// ---------------------------------------------------------------------------

final scenesProvider = NotifierProvider<ScenesNotifier, ScenesState>(ScenesNotifier.new);

class ScenesNotifier extends Notifier<ScenesState> {
  ISceneManager get _sceneManager => ref.read(sceneManagerProvider);

  @override
  ScenesState build() {
    final eventBus = ref.read(eventBusProvider);
    final deviceManager = ref.read(deviceManagerProvider);

    final subs = <StreamSubscription>[
      eventBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged),
      eventBus.on<SceneCreatedEvent>().listen(_onSceneCreated),
      eventBus.on<SceneDeletedEvent>().listen(_onSceneDeleted),
      eventBus.on<SceneUpdatedEvent>().listen(_onSceneUpdated),
      eventBus.on<DeviceManagerReadyEvent>().listen(_onDeviceManagerReady),
      deviceManager.allDeviceEvents.on<DeviceBoundEvent>().listen((_) {
        unawaited(_reload(preserveOrder: true));
      }),
      deviceManager.allDeviceEvents.on<DeviceRemovedEvent>().listen((_) {
        unawaited(_reload(preserveOrder: true));
      }),
      deviceManager.allDeviceEvents.on<DeviceEntityUpdatedEvent>().listen(_onDeviceEntityUpdated),
    ];

    ref.onDispose(() {
      for (final sub in subs) {
        sub.cancel();
      }
    });

    return const ScenesState(scenes: []);
  }

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _reload(preserveOrder: false);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  @visibleForTesting
  Future<void> reload({bool preserveOrder = true}) => _reload(preserveOrder: preserveOrder);

  Future<void> switchCurrentScene(String newSceneID) async {
    if (newSceneID == _sceneManager.current.id || state.isLoading) return;
    state = state.copyWith(switchingSceneId: newSceneID, isLoading: true);
    try {
      await _sceneManager.changeCurrent(newSceneID);
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = ScenesState(scenes: state.scenes, isLoading: false, error: state.error, switchingSceneId: null);
    }
  }

  // ---------------------------------------------------------------------------
  // Internal helpers
  // ---------------------------------------------------------------------------

  Future<void> _reload({required bool preserveOrder}) async {
    final scenes = await _sceneManager.all();
    final sceneStates = <SceneSummaryModel>[];
    for (final scene in scenes) {
      final deviceStats = await _sceneManager.getDeviceStatistics(scene.id);
      sceneStates.add(
        SceneSummaryModel(
          scene: scene,
          totalDeviceCount: deviceStats.totalDeviceCount,
          activeDeviceCount: deviceStats.activeDeviceCount,
          isSelected: scene.id == _sceneManager.current.id,
        ),
      );
    }

    List<SceneSummaryModel> rebuilt;
    if (preserveOrder && state.scenes.isNotEmpty) {
      final mapById = {for (final s in sceneStates) s.id: s};
      rebuilt = [];
      for (final existing in state.scenes) {
        final updated = mapById.remove(existing.id);
        if (updated != null) rebuilt.add(updated);
      }
      final remaining = mapById.values.toList()
        ..sort((a, b) => b.scene.lastAccessTime.compareTo(a.scene.lastAccessTime));
      rebuilt.addAll(remaining);
    } else {
      sceneStates.sort((a, b) => b.scene.lastAccessTime.compareTo(a.scene.lastAccessTime));
      rebuilt = sceneStates;
    }

    if (!preserveOrder && rebuilt.isNotEmpty) {
      final currentId = _sceneManager.current.id;
      final idx = rebuilt.indexWhere((s) => s.id == currentId);
      if (idx > 0) {
        final selected = rebuilt.removeAt(idx);
        rebuilt.insert(0, selected);
      }
    }

    state = state.copyWith(scenes: rebuilt);
  }

  // ---------------------------------------------------------------------------
  // Event handlers
  // ---------------------------------------------------------------------------

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    state = state.copyWith(scenes: state.scenes.map((s) => s.copyWith(isSelected: s.id == event.to.id)).toList());
  }

  void _onSceneCreated(SceneCreatedEvent event) {
    if (!state.isLoading) {
      unawaited(_sceneManager.changeCurrent(event.scene.id).then((_) => _reload(preserveOrder: true)));
    }
  }

  void _onSceneDeleted(SceneDeletedEvent _) {
    if (!state.isLoading) {
      unawaited(
        _sceneManager.getLastAccessed().then((scene) async {
          await _sceneManager.changeCurrent(scene.id);
          await _reload(preserveOrder: true);
        }),
      );
    }
  }

  void _onSceneUpdated(SceneUpdatedEvent event) {
    state = state.copyWith(
      scenes: state.scenes.map((s) => s.id == event.scene.id ? s.copyWith(scene: event.scene) : s).toList(),
    );
  }

  void _onDeviceManagerReady(DeviceManagerReadyEvent _) {
    if (!state.isLoading) unawaited(_reload(preserveOrder: true));
  }

  void _onDeviceEntityUpdated(DeviceEntityUpdatedEvent event) {
    if (event.old.sceneID != event.updated.sceneID) {
      if (!state.isLoading) unawaited(_reload(preserveOrder: true));
    }
  }
}
