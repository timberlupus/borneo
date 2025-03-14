import 'dart:async';

import 'package:borneo_app/models/device_statistics.dart';
import 'package:borneo_app/models/events.dart';
import 'package:borneo_app/models/scene_entity.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/scene_manager.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:event_bus/event_bus.dart';

import '/view_models/base_view_model.dart';

class SceneSummaryViewModel extends BaseViewModel {
  final SceneManager _sceneManager;

  SceneEntity _model;
  SceneEntity get model => _model;

  bool get isSelected => _sceneManager.current.id == _model.id;

  int _totalDeviceCount = 0;
  int get totalDeviceCount => _totalDeviceCount;

  int _activeDeviceCount = 0;
  int get activeDeviceCount => _activeDeviceCount;

  String get id => model.id;
  String get name => model.name;

  late final StreamSubscription<CurrentSceneChangedEvent>
  _currentSceneChangedEventSub;
  late final StreamSubscription<SceneUpdatedEvent> _sceneUpdatedEventSub;

  late final StreamSubscription<DeviceBoundEvent> _deviceBoundEventSub;
  late final StreamSubscription<DeviceRemovedEvent> _deviceRemovedEventSub;

  /*
  late final StreamSubscription<DeviceRemovedEvent> _removedEventSub;
  */

  SceneSummaryViewModel(
    this._model,
    EventBus globalEventBus,
    this._sceneManager,
    DeviceManager dm,
    DeviceStatistics stat,
  ) : _totalDeviceCount = stat.totalDeviceCount,
      _activeDeviceCount = stat.activeDeviceCount {
    //subscribe all events
    _currentSceneChangedEventSub = globalEventBus
        .on<CurrentSceneChangedEvent>()
        .listen(_onCurrentSceneChanged);

    _sceneUpdatedEventSub = globalEventBus.on<SceneUpdatedEvent>().listen(
      _onSceneUpdated,
    );

    _deviceBoundEventSub = dm.deviceEvents.on<DeviceBoundEvent>().listen(
      _onDeviceBound,
    );
    _deviceRemovedEventSub = dm.deviceEvents.on<DeviceRemovedEvent>().listen(
      _onDeviceRemoved,
    );
  }

  @override
  void dispose() {
    _currentSceneChangedEventSub.cancel();
    _sceneUpdatedEventSub.cancel();
    _deviceBoundEventSub.cancel();
    _deviceRemovedEventSub.cancel();
    // _boundEventSub.cancel();
    // _removedEventSub.cancel();
    super.dispose();
  }

  /*
  void _onBound(DeviceBoundEvent event) {
    if (event.device.id == id) {
      _isOnline = true;
      notifyListeners();
    }
  }

  void _onRemoved(DeviceRemovedEvent event) {
    if (event.device.id == id) {
      _isOnline = false;
      notifyListeners();
    }
  }
  */

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    if (event.from.id == id) {
      _model = event.from;
      notifyListeners();
    }
    if (event.to.id == id) {
      _model = event.to;
      notifyListeners();
    }
  }

  void _onDeviceBound(DeviceBoundEvent event) {
    if (isBusy) {
      return;
    }

    _sceneManager.getDeviceStatistics(id).then((stat) {
      _totalDeviceCount = stat.totalDeviceCount;
      _activeDeviceCount = stat.activeDeviceCount;
      notifyListeners();
    });
  }

  void _onDeviceRemoved(DeviceRemovedEvent event) {
    if (isBusy) {
      return;
    }

    _sceneManager.getDeviceStatistics(id).then((stat) {
      _totalDeviceCount = stat.totalDeviceCount;
      _activeDeviceCount = stat.activeDeviceCount;
      notifyListeners();
    });
  }

  void _onSceneUpdated(SceneUpdatedEvent event) {
    if (isBusy) {
      return;
    }
    if (event.scene.id == id) {
      _model = event.scene;
      notifyListeners();
    }
  }
}
