import 'package:borneo_app/models/devices/device_group_entity.dart';
import 'package:borneo_app/services/group_manager.dart';
import 'package:borneo_app/view_models/abstract_screen_view_model.dart';

final class GroupEditArguments {
  final bool isCreation;
  final DeviceGroupEntity? model;

  const GroupEditArguments({required this.isCreation, this.model});
}

class GroupEditViewModel extends AbstractScreenViewModel {
  final GroupManager _groupManager;
  final bool isCreation;
  late final String? id;
  late String name;
  late String notes;

  GroupEditViewModel(
    this._groupManager, {
    required super.globalEventBus,
    required this.isCreation,
    DeviceGroupEntity? model,
    super.logger,
  }) {
    if (isCreation) {
      name = '';
      notes = '';
    } else {
      name = model!.name;
      notes = model.notes;
    }
    id = model?.id;
  }

  Future<void>? _initFuture;
  Future<void>? get initFuture {
    if (isInitialized) return null;
    return _initFuture ??= initialize();
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
        await _groupManager.create(name: name, notes: notes);
      } else {
        await _groupManager.update(id!, name: name, notes: notes);
      }
    } finally {
      setBusy(false);
    }
  }

  Future<void> delete() async {
    assert(!isCreation && !isBusy && isInitialized);
    setBusy(true, notify: false);
    try {
      await _groupManager.delete(id!);
    } catch (e, stackTrace) {
      notifyAppError('Failed to delete group `$name`', error: e, stackTrace: stackTrace);
    } finally {
      setBusy(false, notify: false);
    }
  }
}
