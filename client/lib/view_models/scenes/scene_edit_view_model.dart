import 'package:borneo_app/models/scene_entity.dart';
import 'package:borneo_app/services/scene_manager.dart';
import 'package:borneo_app/view_models/abstract_screen_view_model.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

import '../base_view_model.dart';

final class SceneEditArguments {
  final bool isCreation;
  final SceneEntity? model;

  const SceneEditArguments({required this.isCreation, this.model});
}

class SceneEditViewModel extends AbstractScreenViewModel with ViewModelEventBusMixin {
  final Logger? logger;
  final SceneManager _sceneManager;
  final bool isCreation;
  late final String? id;
  late String name;
  late String notes;

  final bool _deletionAvailable;
  bool get deletionAvailable => _deletionAvailable;

  SceneEditViewModel(
    EventBus globalEventBus,
    this._sceneManager, {
    required this.isCreation,
    SceneEntity? model,
    this.logger,
  }) : _deletionAvailable = !isCreation {
    super.globalEventBus = globalEventBus;
    if (isCreation) {
      name = '';
      notes = '';
    } else {
      name = model!.name;
      notes = model.notes;
    }
    id = model?.id;
  }

  @override
  Future<void> onInitialize() async {
    // nothing to do
  }

  Future<void> submit() async {
    assert(!isBusy && isInitialized);

    setBusy(true);
    try {
      if (isCreation) {
        await _sceneManager.create(name: name, notes: notes);
      } else {
        await _sceneManager.update(id: id!, name: name, notes: notes);
      }
    } catch (e, stackTrace) {
      notifyAppError('Failed to update scene `$name`', error: e, stackTrace: stackTrace);
    } finally {
      setBusy(false);
    }
  }

  Future<void> delete() async {
    assert(!isCreation && !isBusy && isInitialized);
    setBusy(true, notify: false);
    try {
      await _sceneManager.delete(id!);
    } catch (e, stackTrace) {
      notifyAppError('Failed to delete scene `$name`', error: e, stackTrace: stackTrace);
    } finally {
      setBusy(false, notify: false);
    }
  }
}
