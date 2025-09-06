import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';

import '../../../core/models/events.dart';
import '../../../core/services/routine_manager.dart';
import '../../../core/services/scene_manager.dart';
import '../../../core/services/app_notification_service.dart';
import '../models/abstract_routine.dart';

class RoutinesViewModel extends ChangeNotifier {
  final IRoutineManager _routineManager;
  final EventBus _eventBus;
  final Logger? _logger;

  // Keep references only for parity; sceneManager & notification not stored
  RoutinesViewModel(
    this._routineManager,
    ISceneManager sceneManager,
    IAppNotificationService notification,
    this._eventBus,
    this._logger,
  ) {
    _setupEventListeners();
  }

  List<AbstractRoutine> _routines = [];
  bool _isLoading = false;
  String? _error;

  List<AbstractRoutine> get routines => _routines;
  bool get isLoading => _isLoading;
  String? get error => _error;

  late final StreamSubscription<CurrentSceneChangedEvent> _currentSceneChangedSub;
  late final StreamSubscription<CurrentSceneDevicesReloadedEvent> _devicesReloadedSub;
  late final StreamSubscription<DeviceManagerReadyEvent> _deviceManagerReadySub;

  void _setupEventListeners() {
    _currentSceneChangedSub = _eventBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged);
    _devicesReloadedSub = _eventBus.on<CurrentSceneDevicesReloadedEvent>().listen(_onDevicesReloaded);
    _deviceManagerReadySub = _eventBus.on<DeviceManagerReadyEvent>().listen(_onDeviceManagerReady);
  }

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _reloadRoutines();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadRoutines() async {
    try {
      _routines = _routineManager.getAvailableRoutines();
    } catch (e) {
      _logger?.e('Failed to reload routines: $e');
      _error = e.toString();
    }
    notifyListeners();
  }

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    _logger?.d('Scene changed from ${event.from.name} to ${event.to.name}, waiting for devices to reload...');
    // Enter loading state immediately when the current scene changes so the UI
    // can show a loading indicator while devices and routines are reloaded.
    _isLoading = true;
    _error = null;
    _routines = [];
    notifyListeners();
  }

  void _onDevicesReloaded(CurrentSceneDevicesReloadedEvent event) {
    // Devices for the new scene have finished reloading. Refresh routines and
    // exit loading state after refresh completes so the UI updates smoothly.
    unawaited(() async {
      try {
        await _reloadRoutines();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }());
  }

  void _onDeviceManagerReady(DeviceManagerReadyEvent event) {
    _reloadRoutines();
  }

  @override
  void dispose() {
    _currentSceneChangedSub.cancel();
    _devicesReloadedSub.cancel();
    _deviceManagerReadySub.cancel();
    super.dispose();
  }
}
