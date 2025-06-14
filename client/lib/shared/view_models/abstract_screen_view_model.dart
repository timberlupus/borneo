import 'package:borneo_app/shared/view_models/base_view_model.dart';
import 'package:event_bus/event_bus.dart';

abstract class AbstractScreenViewModel extends BaseViewModel with ViewModelEventBusMixin, ViewModelInitFutureMixin {
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  AbstractScreenViewModel({required EventBus globalEventBus, super.logger}) {
    super.globalEventBus = globalEventBus;
  }

  Future<void> initialize() async {
    assert(!_isInitialized);
    enqueueUIJob(() async {
      await onInitialize();
      _isInitialized = true;
    });
  }

  Future<void> onInitialize();
}
