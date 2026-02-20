import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/scenes/views/scenes_screen.dart';
import 'package:borneo_app/features/scenes/view_models/scenes_view_model.dart';
import 'package:event_bus/event_bus.dart';

// core types used by stubs
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:sembast/sembast.dart';

// Minimal stub implementations to satisfy ScenesViewModel constructor
class _DummySceneManager implements ISceneManager {
  @override
  bool get isInitialized => true;

  @override
  SceneEntity get current => throw UnimplementedError();

  @override
  SceneEntity? get located => null;

  @override
  Future<SceneEntity> changeCurrent(String newSceneID) => throw UnimplementedError();
  @override
  Future<SceneEntity> create({required String name, required String notes, String? imagePath}) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id, {Transaction? tx}) => throw UnimplementedError();
  @override
  Future<List<SceneEntity>> all({Transaction? tx}) async => [];
  @override
  Future<SceneEntity> single(String key, {Transaction? tx}) => throw UnimplementedError();
  @override
  Future<DeviceStatistics> getDeviceStatistics(String sceneID) => throw UnimplementedError();
  @override
  Future<SceneEntity> getLastAccessed({CancellationToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<void> initialize(IGroupManager groupManager, IDeviceManager deviceManager) => throw UnimplementedError();
  @override
  Future<SceneEntity> update({
    required String id,
    required String name,
    required String notes,
    String? imagePath,
    Transaction? tx,
  }) => throw UnimplementedError();
}

class _DummyDeviceManager implements IDeviceManager {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// simple scene manager that returns a fixed list and reports whichever
/// item has `isCurrent == true` as the current scene.
class _StubSceneManager implements ISceneManager {
  @override
  bool get isInitialized => true;

  final List<SceneEntity> list;
  _StubSceneManager(this.list);

  @override
  SceneEntity get current => list.firstWhere((s) => s.isCurrent);

  @override
  Future<List<SceneEntity>> all({Transaction? tx}) async => List.from(list);
  @override
  Future<DeviceStatistics> getDeviceStatistics(String sceneID) async => DeviceStatistics(0, 0);

  /// change which item is marked current; returns the updated scene
  @override
  Future<SceneEntity> changeCurrent(String newSceneID) async {
    for (var i = 0; i < list.length; i++) {
      final s = list[i];
      if (s.id == newSceneID) {
        list[i] = s.copyWith(isCurrent: true);
      } else if (s.isCurrent) {
        list[i] = s.copyWith(isCurrent: false);
      }
    }
    return current;
  }

  // unused members
  @override
  SceneEntity? get located => null;
  @override
  Future<SceneEntity> create({required String name, required String notes, String? imagePath}) =>
      throw UnimplementedError();
  @override
  Future<void> delete(String id, {Transaction? tx}) => throw UnimplementedError();
  @override
  Future<SceneEntity> single(String key, {Transaction? tx}) => throw UnimplementedError();
  @override
  Future<SceneEntity> getLastAccessed({CancellationToken? cancelToken}) => throw UnimplementedError();
  @override
  Future<void> initialize(IGroupManager groupManager, IDeviceManager deviceManager) => throw UnimplementedError();
  @override
  Future<SceneEntity> update({
    required String id,
    required String name,
    required String notes,
    String? imagePath,
    Transaction? tx,
  }) => throw UnimplementedError();
}

// subclass ScenesViewModel so provider type matches
class FakeScenesViewModel extends ScenesViewModel {
  bool _overrideLoading = false;

  FakeScenesViewModel() : super(_DummySceneManager(), _DummyDeviceManager(), EventBus(), null);

  @override
  bool get isLoading => _overrideLoading;

  set isLoading(bool v) {
    _overrideLoading = v;
    notifyListeners();
  }
}

void main() {
  testWidgets('action slot remains constant when loading toggles', (WidgetTester tester) async {
    final vm = FakeScenesViewModel();

    // build a minimal scaffold replicating the same app bar logic, avoiding
    // ScenesScreen and translation dependencies.
    await tester.pumpWidget(
      MaterialApp(
        home: AnimatedBuilder(
          animation: vm,
          builder: (context, _) {
            return Scaffold(
              appBar: AppBar(
                actions: [
                  SizedBox(
                    width: kToolbarHeight,
                    child: vm.isLoading
                        ? const Padding(padding: EdgeInsets.all(12.0), child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.add_outlined),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );

    // initially not loading -> should find icon button, not progress indicator
    expect(find.byIcon(Icons.add_outlined), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsNothing);

    // count of actions should be 1 (the SizedBox slot)
    var appBar = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar.actions?.length, 1);

    // toggle loading
    vm.isLoading = true;
    await tester.pump();

    expect(find.byIcon(Icons.add_outlined), findsNothing);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    // still one action slot
    var appBar2 = tester.widget<AppBar>(find.byType(AppBar));
    expect(appBar2.actions?.length, 1);
  });

  group('ScenesViewModel ordering', () {
    test('current scene should be moved to front on initialize', () async {
      final now = DateTime.now();
      final scenes = [
        SceneEntity(id: 'a', name: 'A', isCurrent: false, lastAccessTime: now.subtract(const Duration(days: 2))),
        SceneEntity(id: 'b', name: 'B', isCurrent: true, lastAccessTime: now.subtract(const Duration(days: 1))),
        SceneEntity(id: 'c', name: 'C', isCurrent: false, lastAccessTime: now),
      ];

      final manager = _StubSceneManager(scenes);
      final vm = ScenesViewModel(manager, _DummyDeviceManager(), EventBus(), null);

      await vm.initialize();

      expect(vm.scenes, isNotEmpty);
      expect(
        vm.scenes.first.id,
        equals(manager.current.id),
        reason: 'The current scene should be reordered to index 0',
      );
    });

    test('preserving order does not move newly selected scene to front', () async {
      final now = DateTime.now();
      final scenes = [
        SceneEntity(id: 'a', name: 'A', isCurrent: false, lastAccessTime: now.subtract(const Duration(days: 2))),
        SceneEntity(id: 'b', name: 'B', isCurrent: true, lastAccessTime: now.subtract(const Duration(days: 1))),
        SceneEntity(id: 'c', name: 'C', isCurrent: false, lastAccessTime: now),
      ];

      final manager = _StubSceneManager(scenes);
      final bus = EventBus();
      final vm = ScenesViewModel(manager, _DummyDeviceManager(), bus, null);

      await vm.initialize();
      // initial order has current at front
      final initialOrder = vm.scenes.map((s) => s.id).toList();

      // change current; notify view model via event bus as the real manager would
      await manager.changeCurrent('c');
      bus.fire(
        CurrentSceneChangedEvent(
          SceneEntity(id: 'b', name: 'B', isCurrent: false, lastAccessTime: now.subtract(const Duration(days: 1))),
          manager.current,
        ),
      );

      // order after selection change (should be unchanged)
      final afterSelectOrder = vm.scenes.map((s) => s.id).toList();
      expect(afterSelectOrder, equals(initialOrder));
      expect(vm.scenes.first.id, equals('b'), reason: 'first item remains previous current');
      expect(vm.scenes[1].id, equals('c'), reason: 'new current exists but not moved to first');

      // reloading while preserving order should also not reposition
      await vm.reload(preserveOrder: true);
      final afterReloadOrder = vm.scenes.map((s) => s.id).toList();
      expect(afterReloadOrder, equals(afterSelectOrder));
    });
  });
}
