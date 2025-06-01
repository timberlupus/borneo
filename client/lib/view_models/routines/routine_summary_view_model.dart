import 'package:borneo_app/models/routines/abstract_routine.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/view_models/base_view_model.dart';

class RoutineSummaryViewModel extends BaseViewModel {
  String get name => _model.name;

  bool _isBusy = false;
  bool get isBusy => _isBusy;

  bool _isActive = false;
  bool get isActive => _isActive;
  String get iconAssetPath => _model.iconAssetPath;

  final AbstractRoutine _model;
  final DeviceManager _deviceManager;
  RoutineSummaryViewModel(this._model, this._deviceManager);

  Future<void> executeRoutine() async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      await _model.execute(_deviceManager);
      _isActive = true;
    } catch (e) {
      // handle error if needed
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  Future<void> undoRoutine() async {
    if (_isBusy) return;
    _isBusy = true;
    notifyListeners();
    try {
      await _model.undo(_deviceManager);
      _isActive = false;
    } catch (e) {
      // handle error if needed
    } finally {
      _isBusy = false;
      notifyListeners();
    }
  }

  @override
  void notifyAppError(String message, {Object? error, StackTrace? stackTrace}) {
    // TODO
  }
}
