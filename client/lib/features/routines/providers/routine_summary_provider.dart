import 'dart:async';

import 'package:borneo_app/features/routines/models/abstract_routine.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/routine_manager.dart';
import 'package:borneo_app/features/routines/providers/routines_provider.dart';
import 'package:borneo_app/features/scenes/providers/scenes_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:logger/logger.dart';

/// Routine Summary State
class RoutineSummaryState {
  final AbstractRoutine routine;
  final bool isActive;
  final bool isBusy;
  final String? error;

  const RoutineSummaryState({required this.routine, this.isActive = false, this.isBusy = false, this.error});

  String get name => routine.name;
  String get iconAssetPath => routine.iconAssetPath;

  RoutineSummaryState copyWith({AbstractRoutine? routine, bool? isActive, bool? isBusy, String? error}) {
    return RoutineSummaryState(
      routine: routine ?? this.routine,
      isActive: isActive ?? this.isActive,
      isBusy: isBusy ?? this.isBusy,
      error: error ?? this.error,
    );
  }
}

/// Routine Summary Notifier
class RoutineSummaryNotifier extends StateNotifier<RoutineSummaryState> {
  final IRoutineManager _routineManager;
  final IAppNotificationService _notification;
  final Logger? _logger;

  RoutineSummaryNotifier(AbstractRoutine routine, this._routineManager, this._notification, this._logger)
    : super(RoutineSummaryState(routine: routine));

  Future<void> executeRoutine() async {
    if (state.isBusy) return;

    state = state.copyWith(isBusy: true, error: null);

    try {
      await _routineManager.executeRoutine(state.routine.id);
      state = state.copyWith(isActive: true, isBusy: false);
    } catch (e, stackTrace) {
      _logger?.e(e.toString(), error: e, stackTrace: stackTrace);
      _notification.showError('Routine execution failed', body: e.toString());
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }

  Future<void> undoRoutine() async {
    if (state.isBusy) return;

    state = state.copyWith(isBusy: true, error: null);

    try {
      await _routineManager.undoRoutine(state.routine.id);
      state = state.copyWith(isActive: false, isBusy: false);
    } catch (e, stackTrace) {
      _logger?.e(e.toString(), error: e, stackTrace: stackTrace);
      _notification.showError('Undo routine failed', body: e.toString());
      state = state.copyWith(isBusy: false, error: e.toString());
    }
  }
}

/// Routine Summary Provider - family provider for individual routines
/// Note: This depends on providers from routines_provider.dart being available in scope
final routineSummaryProvider =
    StateNotifierProvider.family<RoutineSummaryNotifier, RoutineSummaryState, AbstractRoutine>((ref, routine) {
      // These providers come from the parent ProviderScope overrides
      final routineManager = ref.watch(routineManagerProvider);
      final notification = ref.watch(appNotificationServiceProvider);
      final logger = ref.watch(loggerProvider);

      return RoutineSummaryNotifier(routine, routineManager, notification, logger);
    }, dependencies: [routineManagerProvider, appNotificationServiceProvider, loggerProvider]);
