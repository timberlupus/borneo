import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';

import '../../../core/models/device_statistics.dart';
import '../../../core/models/events.dart';
import '../../../core/models/scene_entity.dart';
import '../../../core/services/devices/device_manager.dart';
import '../../../core/services/scene_manager.dart';

class SceneSummaryModel {
  final SceneEntity scene;
  final int totalDeviceCount;
  final int activeDeviceCount;
  final bool isSelected;

  const SceneSummaryModel({
    required this.scene,
    required this.totalDeviceCount,
    required this.activeDeviceCount,
    required this.isSelected,
  });

  String get id => scene.id;
  String get name => scene.name;

  SceneSummaryModel copyWith({SceneEntity? scene, int? totalDeviceCount, int? activeDeviceCount, bool? isSelected}) {
    return SceneSummaryModel(
      scene: scene ?? this.scene,
      totalDeviceCount: totalDeviceCount ?? this.totalDeviceCount,
      activeDeviceCount: activeDeviceCount ?? this.activeDeviceCount,
      isSelected: isSelected ?? this.isSelected,
    );
  }
}

class ScenesViewModel extends ChangeNotifier {
  final ISceneManager _sceneManager;
  final EventBus _eventBus;
  final Logger? _logger;

  // deviceManager for future use (parity) and event triggers handled via eventBus
  ScenesViewModel(this._sceneManager, IDeviceManager deviceManager, this._eventBus, this._logger) {
    _setupEventListeners();
  }

  List<SceneSummaryModel> _scenes = [];
  bool _isLoading = false;
  String? _error;

  List<SceneSummaryModel> get scenes => _scenes;
  bool get isLoading => _isLoading;
  String? get error => _error;

  late final StreamSubscription<CurrentSceneChangedEvent> _currentSceneChangedSub;
  late final StreamSubscription<SceneCreatedEvent> _sceneCreatedSub;
  late final StreamSubscription<SceneDeletedEvent> _sceneDeletedSub;
  late final StreamSubscription<SceneUpdatedEvent> _sceneUpdatedSub;
  late final StreamSubscription<DeviceManagerReadyEvent> _deviceManagerReadySub;

  void _setupEventListeners() {
    _currentSceneChangedSub = _eventBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged);
    _sceneCreatedSub = _eventBus.on<SceneCreatedEvent>().listen(_onSceneCreated);
    _sceneDeletedSub = _eventBus.on<SceneDeletedEvent>().listen(_onSceneDeleted);
    _sceneUpdatedSub = _eventBus.on<SceneUpdatedEvent>().listen(_onSceneUpdated);
    _deviceManagerReadySub = _eventBus.on<DeviceManagerReadyEvent>().listen(_onDeviceManagerReady);
  }

  Future<void> initialize() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    try {
      await _reload(preserveOrder: false); // initial load sorts by lastAccessTime
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _reload({bool preserveOrder = true}) async {
    _logger?.d('ScenesViewModel._reload(preserveOrder=$preserveOrder)');
    final scenes = await _sceneManager.all();
    final sceneStates = <SceneSummaryModel>[];
    for (final scene in scenes) {
      final DeviceStatistics deviceStats = await _sceneManager.getDeviceStatistics(scene.id);
      sceneStates.add(
        SceneSummaryModel(
          scene: scene,
          totalDeviceCount: deviceStats.totalDeviceCount,
          activeDeviceCount: deviceStats.activeDeviceCount,
          isSelected: scene.id == _sceneManager.current.id,
        ),
      );
    }
    if (preserveOrder && _scenes.isNotEmpty) {
      // Rebuild list in the existing order; append any new scenes at the end (by recent first)
      final mapById = {for (final s in sceneStates) s.id: s};
      final rebuilt = <SceneSummaryModel>[];
      for (final existing in _scenes) {
        final updated = mapById.remove(existing.id);
        if (updated != null) rebuilt.add(updated);
      }
      // Append remaining (newly added) scenes in lastAccessTime desc
      final remaining = mapById.values.toList()
        ..sort((a, b) => b.scene.lastAccessTime.compareTo(a.scene.lastAccessTime));
      rebuilt.addAll(remaining);
      _scenes = rebuilt;
    } else {
      // Initial or explicit resort: order by lastAccessTime desc
      sceneStates.sort((a, b) => b.scene.lastAccessTime.compareTo(a.scene.lastAccessTime));
      _scenes = sceneStates;
    }
    notifyListeners();
  }

  Future<void> switchCurrentScene(String newSceneID) async {
    if (newSceneID == _sceneManager.current.id || _isLoading) return;
    _isLoading = true;
    notifyListeners();
    try {
      await _sceneManager.changeCurrent(newSceneID);
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    _scenes = _scenes.map((s) => s.copyWith(isSelected: s.id == event.to.id)).toList();
    notifyListeners();
  }

  void _onSceneCreated(SceneCreatedEvent event) {
    if (!_isLoading) {
      _sceneManager.changeCurrent(event.scene.id).then((_) => _reload(preserveOrder: true));
    }
  }

  void _onSceneDeleted(SceneDeletedEvent event) {
    if (!_isLoading)
      _sceneManager.getLastAccessed().then((scene) async {
        await _sceneManager.changeCurrent(scene.id);
        _reload(preserveOrder: true);
      });
  }

  void _onSceneUpdated(SceneUpdatedEvent event) {
    _scenes = _scenes.map((s) => s.id == event.scene.id ? s.copyWith(scene: event.scene) : s).toList();
    notifyListeners();
  }

  void _onDeviceManagerReady(DeviceManagerReadyEvent _) {
    if (!_isLoading) _reload(preserveOrder: true);
  }

  @override
  void dispose() {
    _currentSceneChangedSub.cancel();
    _sceneCreatedSub.cancel();
    _sceneDeletedSub.cancel();
    _sceneUpdatedSub.cancel();
    _deviceManagerReadySub.cancel();
    super.dispose();
  }
}
