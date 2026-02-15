import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

import '../../../core/services/app_notification_service.dart';
import '../../../core/services/chore_manager.dart';
import '../models/abstract_chore.dart';

class ChoreSummaryViewModel extends ChangeNotifier {
  final IChoreManager _choreManager;
  final IAppNotificationService _notification;
  final Logger? _logger;
  final AbstractChore chore;

  ChoreSummaryViewModel(
    this.chore, {
    required IChoreManager choreManager,
    required IAppNotificationService notification,
    required Logger? logger,
  }) : _choreManager = choreManager,
       _notification = notification,
       _logger = logger;

  bool _isActive = false;
  bool _isBusy = false;
  String? _error;

  bool get isActive => _isActive;
  bool get isBusy => _isBusy;
  String? get error => _error;
  String get name => chore.name;
  String get iconAssetPath => chore.iconAssetPath;

  Future<void> init() async {
    try {
      _isActive = await _choreManager.hasHistoryForChore(chore.id);
      notifyListeners();
    } catch (e, st) {
      _logger?.e('Failed to initialize chore state', error: e, stackTrace: st);
    }
  }

  Future<void> executeChore() async {
    if (_isBusy) return;
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _choreManager.executeChore(chore.id);
      _isActive = true;
    } catch (e, st) {
      _logger?.e(e.toString(), error: e, stackTrace: st);
      _notification.showError('Chore execution failed', body: e.toString());
      _error = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> undoChore() async {
    if (_isBusy) return;
    _isBusy = true;
    _error = null;
    notifyListeners();
    try {
      await _choreManager.undoChore(chore.id);
      _isActive = false;
    } catch (e, st) {
      _logger?.e(e.toString(), error: e, stackTrace: st);
      _notification.showError('Undo chore failed', body: e.toString());
      _error = e.toString();
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }
}
