import 'package:borneo_app/models/routines/abstract_routine.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/i_app_notification_service.dart';
import 'package:borneo_app/view_models/base_view_model.dart';

class RoutineSummaryViewModel extends BaseViewModel {
  String get name => _model.name;

  bool _isActive = false;
  bool get isActive => _isActive;
  String get iconAssetPath => _model.iconAssetPath;

  final AbstractRoutine _model;
  final DeviceManager _deviceManager;
  final IAppNotificationService _notification;
  RoutineSummaryViewModel(this._model, this._deviceManager, this._notification, {super.logger});

  Future<void> executeRoutine() async {
    if (super.isBusy) return;
    isBusy = true;
    notifyListeners();
    try {
      await _model.execute(_deviceManager);
      _isActive = true;
    } catch (e, stackTrace) {
      super.logger?.e(e.toString(), error: e, stackTrace: stackTrace);
      _notification.showError('Routine execution failed', body: e.toString());
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  Future<void> undoRoutine() async {
    if (isBusy) {
      return;
    }
    isBusy = true;
    notifyListeners();
    try {
      await _model.undo(_deviceManager);
      _isActive = false;
    } catch (e, stackTrace) {
      super.logger?.e(e.toString(), error: e, stackTrace: stackTrace);
      _notification.showError('Undo routine failed', body: e.toString());
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void notifyAppError(String message, {Object? error, StackTrace? stackTrace}) {
    _notification.showError(message, body: error?.toString());
  }
}
