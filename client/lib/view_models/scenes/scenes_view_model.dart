import 'dart:async';

import 'package:borneo_app/models/events.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/routine_manager.dart';
import 'package:borneo_app/services/scene_manager.dart';
import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:borneo_app/view_models/routines/routine_summary_view_model.dart';
import 'package:borneo_app/view_models/scenes/scene_summary_view_model.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/foundation.dart';

class ScenesViewModel extends BaseViewModel with ViewModelEventBusMixin {
  final List<SceneSummaryViewModel> _scenes = [];
  final SceneManager _sceneManager;
  final DeviceManager _deviceManager;
  final RoutineManager _routineManager;

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  late final StreamSubscription<CurrentSceneChangedEvent> _currentSceneChangedEventSub;
  late final StreamSubscription<SceneCreatedEvent> _sceneCreatedEventSub;
  late final StreamSubscription<SceneDeletedEvent> _sceneDeletedEventSub;
  late final StreamSubscription<SceneUpdatedEvent> _sceneUpdatedEventSub;

  List<SceneSummaryViewModel> get scenes => _scenes;

  final ValueNotifier<List<RoutineSummaryViewModel>> _routines = ValueNotifier<List<RoutineSummaryViewModel>>([]);
  ValueNotifier<List<RoutineSummaryViewModel>> get routines => _routines;

  ScenesViewModel(EventBus globalEventBus, this._sceneManager, this._deviceManager, this._routineManager) {
    super.globalEventBus = globalEventBus;

    //event subscriptions
    _currentSceneChangedEventSub = super.globalEventBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged);

    _sceneCreatedEventSub = super.globalEventBus.on<SceneCreatedEvent>().listen(_onSceneCreated);
    _sceneDeletedEventSub = super.globalEventBus.on<SceneDeletedEvent>().listen(_onSceneDeleted);
    _sceneUpdatedEventSub = super.globalEventBus.on<SceneUpdatedEvent>().listen(_onSceneUpdated);
  }

  Future<void> initialize() async {
    assert(!isInitialized);
    super.setBusy(true, notify: false);
    try {
      await _reload();
    } finally {
      super.setBusy(false, notify: false);
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    if (!super.isDisposed) {
      _currentSceneChangedEventSub.cancel();
      _sceneCreatedEventSub.cancel();
      _sceneDeletedEventSub.cancel();
      _sceneUpdatedEventSub.cancel();
      super.dispose();
    }
  }

  Future<void> _reload() async {
    for (final sceneViewModel in _scenes) {
      sceneViewModel.dispose();
    }
    _scenes.clear();

    final scenes = await _sceneManager.all();

    final sceneViewModels = <SceneSummaryViewModel>[];

    for (final scene in scenes) {
      final deviceStat = await _sceneManager.getDeviceStatistics(_sceneManager.current.id);
      final vm = SceneSummaryViewModel(scene, globalEventBus, _sceneManager, _deviceManager, deviceStat);
      sceneViewModels.add(vm);

      _reloadRoutines();
    }

    sceneViewModels.sort((a, b) {
      if (a.model.isCurrent && !b.model.isCurrent) {
        return -1;
      } else if (!a.model.isCurrent && b.model.isCurrent) {
        return 1;
      } else {
        return b.model.lastAccessTime.compareTo(a.model.lastAccessTime);
      }
    });

    _scenes.addAll(sceneViewModels);
  }

  void _reloadRoutines() {
    final routines = _routineManager.getAvailableRoutines();
    for (final r in _routines.value) {
      r.dispose();
    }
    _routines.value = routines.map((r) => RoutineSummaryViewModel(r)).toList();
  }

  Future<void> switchCurrentScene(String newSceneID) async {
    assert(!isBusy && _isInitialized);

    if (newSceneID == _sceneManager.current.id) {
      return;
    }

    super.setBusy(true, notify: false);
    try {
      await _sceneManager.changeCurrent(newSceneID);
    } finally {
      super.setBusy(false, notify: false);
    }
  }

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    assert(!isDisposed);
    _deviceManager.rebindAll().then((_) {
      for (final scene in _scenes) {
        scene.notifyListeners();
      }
      _reloadRoutines();
    }); // TODO move it to event
  }

  void _onSceneDeleted(SceneDeletedEvent event) {
    if (isBusy) {
      return;
    }
    _reload().then((_) => notifyListeners());
  }

  void _onSceneUpdated(SceneUpdatedEvent event) {
    /*
    if (isBusy) {
      return;
    }
    for (final svm in _scenes) {
      if (svm.id == event.scene.id) {
        svm.notifyListeners();
        break;
      }
    }
    */
  }

  void _onSceneCreated(SceneCreatedEvent event) {
    if (isBusy) {
      return;
    }
    _reload().then((_) => notifyListeners());
  }
}
