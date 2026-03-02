import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/providers.dart';
import '../../../core/services/scene_manager.dart';
import '../models/scene_edit_arguments.dart';

// ---------------------------------------------------------------------------
// Immutable state
// ---------------------------------------------------------------------------

@immutable
class SceneEditState {
  final String name;
  final String notes;
  final String? imagePath;
  final bool isCreation;

  /// `null` when [isCreation] is true.
  final String? id;
  final bool isBusy;

  const SceneEditState({
    required this.name,
    required this.notes,
    required this.isCreation,
    this.imagePath,
    this.id,
    this.isBusy = false,
  });

  bool get deletionAvailable => !isCreation;

  SceneEditState copyWith({
    String? name,
    String? notes,
    Object? imagePath = _sentinel,
    bool? isCreation,
    Object? id = _sentinel,
    bool? isBusy,
  }) {
    return SceneEditState(
      name: name ?? this.name,
      notes: notes ?? this.notes,
      imagePath: imagePath == _sentinel ? this.imagePath : (imagePath as String?),
      isCreation: isCreation ?? this.isCreation,
      id: id == _sentinel ? this.id : (id as String?),
      isBusy: isBusy ?? this.isBusy,
    );
  }
}

const _sentinel = Object();

// ---------------------------------------------------------------------------
// Provider overrides injected by the screen
// ---------------------------------------------------------------------------

/// Holds the route arguments for the current edit session.
/// Must be overridden inside a [ProviderScope] before [sceneEditProvider] is
/// first read.
final sceneEditArgsProvider = Provider<SceneEditArguments>(
  (ref) => throw UnimplementedError('sceneEditArgsProvider must be overridden'),
);

// ---------------------------------------------------------------------------
// Notifier + provider
// ---------------------------------------------------------------------------

final sceneEditProvider = NotifierProvider<SceneEditNotifier, SceneEditState>(SceneEditNotifier.new);

class SceneEditNotifier extends Notifier<SceneEditState> {
  @override
  SceneEditState build() {
    final args = ref.read(sceneEditArgsProvider);
    if (args.isCreation) {
      return const SceneEditState(name: '', notes: '', isCreation: true);
    }
    final model = args.model!;
    return SceneEditState(
      name: model.name,
      notes: model.notes,
      imagePath: model.imagePath,
      isCreation: false,
      id: model.id,
    );
  }

  ISceneManager get _sceneManager => ref.read(sceneManagerProvider);

  void updateName(String name) => state = state.copyWith(name: name);

  void updateNotes(String notes) => state = state.copyWith(notes: notes);

  void setImagePath(String? path) => state = state.copyWith(imagePath: path);

  /// Persists the scene (create or update).  Throws on failure so the caller
  /// can handle error presentation.
  Future<void> submit() async {
    state = state.copyWith(isBusy: true);
    try {
      if (state.isCreation) {
        await _sceneManager.create(name: state.name, notes: state.notes, imagePath: state.imagePath);
      } else {
        await _sceneManager.update(id: state.id!, name: state.name, notes: state.notes, imagePath: state.imagePath);
      }
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }

  /// Deletes the scene.  Throws on failure so the caller can handle error
  /// presentation.
  Future<void> delete() async {
    assert(!state.isCreation);
    state = state.copyWith(isBusy: true);
    try {
      await _sceneManager.delete(state.id!);
    } finally {
      state = state.copyWith(isBusy: false);
    }
  }
}
