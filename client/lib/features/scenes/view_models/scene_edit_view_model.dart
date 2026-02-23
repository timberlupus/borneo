import 'package:flutter/foundation.dart';

import '../../../core/models/scene_entity.dart';
import '../../../core/services/scene_manager.dart';

class SceneEditViewModel extends ChangeNotifier {
  final ISceneManager _sceneManager;
  final bool isCreation;
  final String? id;

  SceneEditViewModel(this._sceneManager, {required this.isCreation, SceneEntity? model})
    : id = model?.id,
      _name = model?.name ?? '',
      _notes = model?.notes ?? '',
      _imagePath = model?.imagePath;

  String _name;
  String _notes;
  String? _imagePath;
  bool _isLoading = false;
  // Note: errors are surfaced by throwing exceptions rather than
  // storing string codes.  View code should catch and inspect
  // specific exception types.
  String get name => _name;
  String get notes => _notes;
  String? get imagePath => _imagePath;
  bool get isLoading => _isLoading;
  bool get deletionAvailable => !isCreation;

  void updateName(String name) {
    _name = name;
    notifyListeners();
  }

  void updateNotes(String notes) {
    _notes = notes;
    notifyListeners();
  }

  void setImagePath(String? path) {
    _imagePath = path;
    notifyListeners();
  }

  Future<bool> submit() async {
    if (_isLoading) return false;
    _isLoading = true;
    notifyListeners();
    try {
      if (isCreation) {
        await _sceneManager.create(name: _name, notes: _notes, imagePath: _imagePath);
      } else {
        await _sceneManager.update(id: id!, name: _name, notes: _notes, imagePath: _imagePath);
      }
      return true;
    } catch (e) {
      // caller may want to display a message; rethrow or wrap if needed
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Attempts to delete the scene.  Throws if the operation fails.
  /// View code should catch the specific exceptions defined in
  /// `scene_deletion_exceptions.dart` and react accordingly.
  Future<void> delete() async {
    if (isCreation || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _sceneManager.delete(id!);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
