import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:sembast/sembast.dart';

/// Lightweight stub implementation that is frequently reused across tests.
///
/// Most tests only require a handful of members (``current``, ``all`` and
/// occasionally ``changeCurrent``) so the class provides a minimal in-memory
/// list and statistics map.  The implementation is essentially the same as
/// the private versions that were previously copied into individual test
/// files.
class StubSceneManager implements ISceneManager {
  final List<SceneEntity> _scenes;
  final Map<String, DeviceStatistics> statsByScene = {};

  StubSceneManager([List<SceneEntity>? initial]) : _scenes = List.from(initial ?? []);

  @override
  bool get isInitialized => true;

  @override
  SceneEntity get current => _scenes.firstWhere((s) => s.isCurrent, orElse: () => throw StateError('no current scene'));

  @override
  SceneEntity? get located => null;

  @override
  Future<List<SceneEntity>> all({Transaction? tx}) async => List.from(_scenes);

  @override
  Future<SceneEntity> changeCurrent(String newSceneID) async {
    for (var i = 0; i < _scenes.length; i++) {
      final s = _scenes[i];
      if (s.id == newSceneID) {
        _scenes[i] = s.copyWith(isCurrent: true);
      } else if (s.isCurrent) {
        _scenes[i] = s.copyWith(isCurrent: false);
      }
    }
    return current;
  }

  @override
  Future<SceneEntity> create({required String name, required String notes, String? imagePath}) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id, {Transaction? tx}) => throw UnimplementedError();
  @override
  Future<SceneEntity> single(String key, {Transaction? tx}) => throw UnimplementedError();
  @override
  Future<DeviceStatistics> getDeviceStatistics(String sceneID) async => statsByScene[sceneID] ?? DeviceStatistics(0, 0);
  @override
  Future<SceneEntity> getLastAccessed({CancellationToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<void> initialize(IGroupManager groupManager, IDeviceManager deviceManager) => throw UnimplementedError();

  // allow tests to override current scene directly
  set currentScene(SceneEntity scene) {
    // ensure scene is in list and mark it current
    var idx = _scenes.indexWhere((s) => s.id == scene.id);
    if (idx == -1) {
      _scenes.insert(0, scene);
    } else {
      _scenes[idx] = scene;
    }
    // clear others
    for (var i = 0; i < _scenes.length; i++) {
      if (_scenes[i].id != scene.id && _scenes[i].isCurrent) {
        _scenes[i] = _scenes[i].copyWith(isCurrent: false);
      }
    }
  }

  /// alias to make existing tests compile
  SceneEntity get currentScene => current;

  // all remaining members intentionally unimplemented; tests should not reach them
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
