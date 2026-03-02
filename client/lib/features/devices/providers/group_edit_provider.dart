import 'package:borneo_app/core/providers.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

// ---------------------------------------------------------------------------
// Route arguments
// ---------------------------------------------------------------------------

@immutable
final class GroupEditArguments {
  final bool isCreation;
  final DeviceGroupEntity? model;

  const GroupEditArguments({required this.isCreation, this.model});
}

// ---------------------------------------------------------------------------
// Immutable UI state
// ---------------------------------------------------------------------------

@immutable
class GroupEditState {
  final String name;
  final String notes;

  /// `null` when [isCreation] is true.
  final String? id;
  final bool isCreation;
  final bool isBusy;

  const GroupEditState({
    required this.name,
    required this.notes,
    required this.isCreation,
    this.id,
    this.isBusy = false,
  });

  GroupEditState copyWith({String? name, String? notes, String? id, bool? isCreation, bool? isBusy}) {
    return GroupEditState(
      name: name ?? this.name,
      notes: notes ?? this.notes,
      id: id ?? this.id,
      isCreation: isCreation ?? this.isCreation,
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

// ---------------------------------------------------------------------------
// Provider overrides injected by the screen
// ---------------------------------------------------------------------------

/// Holds the route arguments for the current edit session.
/// Must be overridden inside a [ProviderScope] before [groupEditProvider]
/// is first read.
final groupEditArgsProvider = Provider<GroupEditArguments>(
  (ref) => throw UnimplementedError('groupEditArgsProvider must be overridden'),
);

// ---------------------------------------------------------------------------
// Notifier + provider
// ---------------------------------------------------------------------------

final groupEditProvider = NotifierProvider<GroupEditNotifier, GroupEditState>(GroupEditNotifier.new);

class GroupEditNotifier extends Notifier<GroupEditState> {
  @override
  GroupEditState build() {
    final args = ref.read(groupEditArgsProvider);
    if (args.isCreation) {
      return const GroupEditState(name: '', notes: '', isCreation: true);
    }
    final model = args.model!;
    return GroupEditState(name: model.name, notes: model.notes, id: model.id, isCreation: false);
  }

  /// Persists the group (create or update).  Throws on failure so the caller
  /// can handle error presentation.
  Future<void> submit({required String name, required String notes}) async {
    state = state.copyWith(isBusy: true);
    try {
      final groupManager = ref.read(groupManagerProvider);
      if (state.isCreation) {
        await groupManager.create(name: name, notes: notes);
      } else {
        await groupManager.update(state.id!, name: name, notes: notes);
      }
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Deletes the group.  Throws on failure so the caller can handle error
  /// presentation.
  Future<void> delete() async {
    assert(!state.isCreation);
    state = state.copyWith(isBusy: true);
    try {
      final groupManager = ref.read(groupManagerProvider);
      await groupManager.delete(state.id!);
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }
}
