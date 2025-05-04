import 'package:borneo_app/models/routines/abstract_routine.dart';
import 'package:borneo_app/view_models/base_view_model.dart';

class RoutineSummaryViewModel extends BaseViewModel {
  String get name => _model.name;

  final bool _isActive = false;
  bool get isActive => _isActive;
  String get iconAssetPath => _model.iconAssetPath;

  final AbstractRoutine _model;
  RoutineSummaryViewModel(this._model);

  @override
  void notifyAppError(String message, {Object? error, StackTrace? stackTrace}) {
    // TODO
  }

}
