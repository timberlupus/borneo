import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/exceptions/scene_deletion_exceptions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Scene Edit State
class SceneEditState {
  final String name;
  final String notes;
  final String? imagePath;
  final bool isLoading;
  final String? error;

  const SceneEditState({this.name = '', this.notes = '', this.imagePath, this.isLoading = false, this.error});

  SceneEditState copyWith({String? name, String? notes, String? imagePath, bool? isLoading, String? error}) {
    return SceneEditState(
      name: name ?? this.name,
      notes: notes ?? this.notes,
      imagePath: imagePath ?? this.imagePath,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

/// Scene Edit Arguments
final class SceneEditArguments {
  final bool isCreation;
  final SceneEntity? model;

  const SceneEditArguments({required this.isCreation, this.model});
}

/// Scene Edit Notifier
class SceneEditNotifier extends StateNotifier<SceneEditState> {
  final ISceneManager _sceneManager;
  final bool isCreation;
  final String? id;

  SceneEditNotifier(this._sceneManager, {required this.isCreation, SceneEntity? model})
    : id = model?.id,
      super(SceneEditState(name: model?.name ?? '', notes: model?.notes ?? '', imagePath: model?.imagePath));

  bool get deletionAvailable => !isCreation;

  void updateName(String name) {
    state = state.copyWith(name: name);
  }

  void updateNotes(String notes) {
    state = state.copyWith(notes: notes);
  }

  void setImagePath(String? path) {
    state = state.copyWith(imagePath: path);
  }

  Future<bool> submit() async {
    if (state.isLoading) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      if (isCreation) {
        await _sceneManager.create(name: state.name, notes: state.notes, imagePath: state.imagePath);
      } else {
        await _sceneManager.update(id: id!, name: state.name, notes: state.notes, imagePath: state.imagePath);
      }
      state = state.copyWith(isLoading: false);
      return true;
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to ${isCreation ? 'create' : 'update'} scene `${state.name}`: $e',
      );
      return false;
    }
  }

  Future<bool> delete() async {
    if (isCreation || state.isLoading) return false;

    state = state.copyWith(isLoading: true, error: null);

    try {
      await _sceneManager.delete(id!);
      state = state.copyWith(isLoading: false);
      return true;
    } on CannotDeleteLastSceneException {
      state = state.copyWith(isLoading: false, error: 'last_scene');
      return false;
    } on SceneContainsDevicesOrGroupsException {
      state = state.copyWith(isLoading: false, error: 'devices_or_groups');
      return false;
    } catch (e) {
      state = state.copyWith(isLoading: false, error: 'unknown');
      return false;
    }
  }
}

/// Scene Edit Provider
final sceneEditProvider = StateNotifierProvider.family
    .autoDispose<SceneEditNotifier, SceneEditState, SceneEditArguments>((ref, args) {
      // 这个 provider 需要通过 override 来提供 SceneManager
      throw UnimplementedError('SceneEditProvider must be overridden with actual SceneManager instance');
    });
