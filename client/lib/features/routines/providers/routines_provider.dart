import 'dart:async';

import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/routine_manager.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/features/routines/models/abstract_routine.dart';
import 'package:borneo_app/features/scenes/providers/scenes_provider.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Routines State
class RoutinesState {
  final List<AbstractRoutine> routines;
  final bool isLoading;
  final String? error;

  const RoutinesState({this.routines = const [], this.isLoading = false, this.error});

  RoutinesState copyWith({List<AbstractRoutine>? routines, bool? isLoading, String? error}) {
    return RoutinesState(
      routines: routines ?? this.routines,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Routines Notifier
class RoutinesNotifier extends StateNotifier<RoutinesState> {
  final IRoutineManager _routineManager;
  final EventBus _eventBus;
  final Logger? _logger;

  late final StreamSubscription<CurrentSceneChangedEvent> _currentSceneChangedSub;
  late final StreamSubscription<CurrentSceneDevicesReloadedEvent> _devicesReloadedSub;
  late final StreamSubscription<DeviceManagerReadyEvent> _deviceManagerReadySub;

  RoutinesNotifier(
    this._routineManager,
    ISceneManager sceneManager, // Used for event listening only
    IAppNotificationService notification, // Keep for compatibility but not store
    this._eventBus,
    this._logger,
  ) : super(const RoutinesState()) {
    _setupEventListeners();
  }

  void _setupEventListeners() {
    _currentSceneChangedSub = _eventBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged);
    _devicesReloadedSub = _eventBus.on<CurrentSceneDevicesReloadedEvent>().listen(_onDevicesReloaded);
    _deviceManagerReadySub = _eventBus.on<DeviceManagerReadyEvent>().listen(_onDeviceManagerReady);
  }

  Future<void> initialize() async {
    state = state.copyWith(isLoading: true, error: null);
    try {
      await _reloadRoutines();
    } catch (e) {
      state = state.copyWith(error: e.toString());
    } finally {
      state = state.copyWith(isLoading: false);
    }
  }

  Future<void> _reloadRoutines() async {
    try {
      final routines = _routineManager.getAvailableRoutines();
      state = state.copyWith(routines: routines);
    } catch (e) {
      _logger?.e('Failed to reload routines: $e');
      state = state.copyWith(error: e.toString());
    }
  }

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    // Don't reload routines immediately - wait for devices to be reloaded first
    _logger?.d('Scene changed from ${event.from.name} to ${event.to.name}, waiting for devices to reload...');
  }

  void _onDevicesReloaded(CurrentSceneDevicesReloadedEvent event) {
    _reloadRoutines();
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

/// Routines specific providers
final routineManagerProvider = Provider<IRoutineManager>((ref) {
  throw UnimplementedError('RoutineManager must be provided by context');
});

final appNotificationServiceProvider = Provider<IAppNotificationService>((ref) {
  throw UnimplementedError('IAppNotificationService must be provided by context');
});

/// Routines Provider
final routinesProvider = StateNotifierProvider<RoutinesNotifier, RoutinesState>(
  (ref) {
    final routineManager = ref.watch(routineManagerProvider);
    final sceneManager = ref.watch(sceneManagerProvider);
    final notification = ref.watch(appNotificationServiceProvider);
    final eventBus = ref.watch(eventBusProvider);
    final logger = ref.watch(loggerProvider);

    return RoutinesNotifier(routineManager, sceneManager, notification, eventBus, logger);
  },
  dependencies: [
    routineManagerProvider,
    sceneManagerProvider,
    appNotificationServiceProvider,
    eventBusProvider,
    loggerProvider,
  ],
);
