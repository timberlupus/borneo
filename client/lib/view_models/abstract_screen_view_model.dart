import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:event_bus/event_bus.dart';

abstract class AbstractScreenViewModel extends BaseViewModel with ViewModelEventBusMixin {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AbstractScreenViewModel({required EventBus globalEventBus, super.logger}) {
    super.globalEventBus = globalEventBus;
  }

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
