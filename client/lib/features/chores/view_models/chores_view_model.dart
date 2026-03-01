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
  bool _isLoading = true;
  String? _error;

  List<AbstractChore> get chores => _chores;
  bool get isLoading => _isLoading;
  String? get error => _error;

  late final StreamSubscription<ChoresChangedEvent> _choresChangedSub;

  void _setupEventListeners() {
    _choresChangedSub = _eventBus.on<ChoresChangedEvent>().listen(_onChoresChanged);
  }

  Future<void> initialize() async {
    assert(_isLoading);
    _error = null;
    try {
      await _reloadChores();
      notifyListeners();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
    }
  }

  Future<void> refresh() async {
    await _reloadChores();
    notifyListeners();
  }

  Future<void> _reloadChores() async {
    // clear the list up-front so the UI can drop whatever was showing
    _chores = [];
    try {
      _chores = _choreManager.getAvailableChores();
    } catch (e, stackTrace) {
      _logger?.e('Failed to reload chores: $e', error: e, stackTrace: stackTrace);
      _error = e.toString();
    }
  }

  void _onChoresChanged(ChoresChangedEvent event) {
    _logger?.d('Chores changed for scene: ${event.scene.name}, reloading chores...');
    unawaited(() async {
      try {
        _isLoading = true;
        _error = null;
        // notify early so callers can show a spinner immediately
        notifyListeners();
        await _reloadChores();
      } finally {
        _isLoading = false;
        notifyListeners();
      }
    }());
  }

  @override
  void dispose() {
    _choresChangedSub.cancel();
    super.dispose();
  }

  /// **TEST ONLY**: allow forcing the loading flag so widgets can react.
  ///
  /// The normal code path sets this when chores change events occur.  This
  /// helper makes it easier to write deterministic unit/widget tests.
  @visibleForTesting
  void setLoadingFlag(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }
}
