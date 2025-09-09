import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';

import '../../../core/models/events.dart';
import '../../../core/services/chore_manager.dart';
import '../../../core/services/scene_manager.dart';
import '../../../core/services/app_notification_service.dart';
import '../models/abstract_chore.dart';

class ChoresViewModel extends ChangeNotifier {
  final IChoreManager _choreManager;
  final EventBus _eventBus;
  final Logger? _logger;

  // Keep references only for parity; sceneManager & notification not stored
  ChoresViewModel(
    this._choreManager,
    ISceneManager sceneManager,
    IAppNotificationService notification,
    this._eventBus,
    this._logger,
  ) {
    _setupEventListeners();
  }

  List<AbstractChore> _chores = [];
  bool _isLoading = false;
  String? _error;

  List<AbstractChore> get chores => _chores;
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
      await _reloadChores();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reloadChores() async {
    try {
      _chores = _choreManager.getAvailableChores();
    } catch (e) {
      _logger?.e('Failed to reload chores: $e');
      _error = e.toString();
    }
    notifyListeners();
  }

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    _logger?.d('Scene changed from ${event.from.name} to ${event.to.name}, waiting for devices to reload...');
    // Enter loading state immediately when the current scene changes so the UI
    // can show a loading indicator while devices and chores are reloaded.
    _isLoading = true;
    _error = null;
    _chores = [];
    notifyListeners();
  }

  void _onDevicesReloaded(CurrentSceneDevicesReloadedEvent event) {
    // Devices for the new scene have finished reloading. Refresh chores and
    // exit loading state after refresh completes so the UI updates smoothly.
    unawaited(() async {
      try {
        await _reloadChores();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }());
  }

  void _onDeviceManagerReady(DeviceManagerReadyEvent event) {
    _reloadChores();
  }

  @override
  void dispose() {
    _currentSceneChangedSub.cancel();
    _devicesReloadedSub.cancel();
    _deviceManagerReadySub.cancel();
    super.dispose();
  }
}
