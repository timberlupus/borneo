import 'package:borneo_app/view_models/base_view_model.dart';

abstract class AbstractScreenViewModel extends BaseViewModel with ViewModelEventBusMixin {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AbstractScreenViewModel();

  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    try {
      await onInitialize();
    } finally {
      _isInitialized = true;
    }
  }

  Future<void> onInitialize();
}
