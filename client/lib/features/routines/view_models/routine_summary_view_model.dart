import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../../core/services/app_notification_service.dart';
import '../../../core/services/routine_manager.dart';
import '../models/abstract_routine.dart';

class RoutineSummaryViewModel extends ChangeNotifier {
  final IRoutineManager _routineManager;
  final IAppNotificationService _notification;
  final Logger? _logger;
  final AbstractRoutine routine;

  RoutineSummaryViewModel(
    this.routine, {
    required IRoutineManager routineManager,
    required IAppNotificationService notification,
    required Logger? logger,
  }) : _routineManager = routineManager,
       _notification = notification,
       _logger = logger;

  bool _isActive = false;
  bool _isBusy = false;
  String? _error;

  bool get isActive => _isActive;
  bool get isBusy => _isBusy;
  String? get error => _error;
  String get name => routine.name;
  String get iconAssetPath => routine.iconAssetPath;

  Future<void> executeRoutine() async {
    if (_isBusy) return;
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _routineManager.executeRoutine(routine.id);
      _isActive = true;
    } catch (e, st) {
      _logger?.e(e.toString(), error: e, stackTrace: st);
      _notification.showError('Routine execution failed', body: e.toString());
      _error = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> undoRoutine() async {
    if (_isBusy) return;
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _routineManager.undoRoutine(routine.id);
      _isActive = false;
    } catch (e, st) {
      _logger?.e(e.toString(), error: e, stackTrace: st);
      _notification.showError('Undo routine failed', body: e.toString());
      _error = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
