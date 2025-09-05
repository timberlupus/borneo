import 'package:flutter/foundation.dart';

import '../../../core/models/scene_entity.dart';
import '../../../core/services/scene_manager.dart';
import '../../../core/exceptions/scene_deletion_exceptions.dart';

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
  String? _error;

  String get name => _name;
  String get notes => _notes;
  String? get imagePath => _imagePath;
  bool get isLoading => _isLoading;
  String? get error => _error;
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
    _error = null;
    notifyListeners();
    try {
      if (isCreation) {
        await _sceneManager.create(name: _name, notes: _notes, imagePath: _imagePath);
      } else {
        await _sceneManager.update(id: id!, name: _name, notes: _notes, imagePath: _imagePath);
      }
      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      _isLoading = false;
      _error = 'Failed to ${isCreation ? 'create' : 'update'} scene `$_name`: $e';
      notifyListeners();
      return false;
    }
  }

  Future<bool> delete() async {
    if (isCreation || _isLoading) return false;
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _sceneManager.delete(id!);
      _isLoading = false;
      notifyListeners();
      return true;
    } on CannotDeleteLastSceneException {
      _isLoading = false;
      _error = 'last_scene';
      notifyListeners();
      return false;
    } on SceneContainsDevicesOrGroupsException {
      _isLoading = false;
      _error = 'devices_or_groups';
      notifyListeners();
      return false;
    } catch (_) {
      _isLoading = false;
      _error = 'unknown';
      notifyListeners();
      return false;
    }
  }
}
