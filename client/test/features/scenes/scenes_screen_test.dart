import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:event_bus/event_bus.dart';

import 'package:borneo_app/features/scenes/view_models/scenes_view_model.dart';

// kernel abstractions types
import 'package:borneo_kernel_abstractions/events.dart' show DeviceBoundEvent, DeviceRemovedEvent;

// core types used by stubs
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/events.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/models/device_statistics.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:sembast/sembast.dart';
import '../../mocks/mocks.dart';

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

// subclass ScenesViewModel so provider type matches
class FakeScenesViewModel extends ScenesViewModel {
  bool _overrideLoading = false;

  FakeScenesViewModel() : super(_DummySceneManager(), StubDeviceManager(), EventBus(), null);

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

      final manager = StubSceneManager(scenes);
      final vm = ScenesViewModel(manager, StubDeviceManager(), EventBus(), null);

      await vm.initialize();

      expect(vm.scenes, isNotEmpty);
      expect(
        vm.scenes.first.id,
        equals(manager.current.id),
        reason: 'The current scene should be reordered to index 0',
      );
    });

    test('device bound/removed events trigger statistics reload', () async {
      final now = DateTime.now();
      final scenes = [SceneEntity(id: 'a', name: 'A', isCurrent: true, lastAccessTime: now)];
      final manager = StubSceneManager(scenes);
      manager.statsByScene['a'] = DeviceStatistics(1, 1);
      final deviceBus = _StubDeviceManager();
      final vm = ScenesViewModel(manager, deviceBus, EventBus(), null);

      await vm.initialize();
      expect(vm.scenes.first.activeDeviceCount, equals(1));

      // simulate device becoming active in scene 'a'
      manager.statsByScene['a'] = DeviceStatistics(1, 2);
      final boundDevice = DeviceEntity(
        id: 'd1',
        address: Uri.parse('coap://localhost'),
        fingerprint: 'fp',
        sceneID: 'a',
        driverID: 'drv',
        compatible: 'foo',
        name: 'D1',
        model: 'M',
      );
      deviceBus.allDeviceEvents.fire(DeviceBoundEvent(boundDevice));
      // allow reload to complete
      await Future<void>.delayed(Duration.zero);
      expect(vm.scenes.first.activeDeviceCount, equals(2));

      // simulate device removed
      manager.statsByScene['a'] = DeviceStatistics(1, 1);
      deviceBus.allDeviceEvents.fire(DeviceRemovedEvent(boundDevice));
      await Future<void>.delayed(Duration.zero);
      expect(vm.scenes.first.activeDeviceCount, equals(1));
    });

    test('moving device between scenes causes reload', () async {
      final now = DateTime.now();
      final scenes = [
        SceneEntity(id: 'a', name: 'A', isCurrent: true, lastAccessTime: now),
        SceneEntity(id: 'b', name: 'B', isCurrent: false, lastAccessTime: now),
      ];
      final manager = StubSceneManager(scenes);
      manager.statsByScene['a'] = DeviceStatistics(1, 1);
      manager.statsByScene['b'] = DeviceStatistics(0, 0);
      final deviceBus = _StubDeviceManager();
      final vm = ScenesViewModel(manager, deviceBus, EventBus(), null);
      await vm.initialize();
      expect(vm.scenes.first.activeDeviceCount, equals(1));
      expect(vm.scenes.last.activeDeviceCount, equals(0));

      // move device from a to b
      final old = DeviceEntity(
        id: 'd2',
        address: Uri.parse('coap://localhost'),
        fingerprint: 'fp2',
        sceneID: 'a',
        driverID: 'drv',
        compatible: 'foo',
        name: 'D2',
        model: 'M',
      );
      final updated = DeviceEntity(
        id: 'd2',
        address: Uri.parse('coap://localhost'),
        fingerprint: 'fp2',
        sceneID: 'b', // moved
        driverID: 'drv',
        compatible: 'foo',
        name: 'D2',
        model: 'M',
      );
      manager.statsByScene['a'] = DeviceStatistics(1, 0);
      manager.statsByScene['b'] = DeviceStatistics(1, 1);
      deviceBus.allDeviceEvents.fire(DeviceEntityUpdatedEvent(old, updated));
      await Future<void>.delayed(Duration.zero);

      expect(vm.scenes.first.activeDeviceCount, equals(0));
      expect(vm.scenes.last.activeDeviceCount, equals(1));
    });

    test('preserving order does not move newly selected scene to front', () async {
      final now = DateTime.now();
      final scenes = [
        SceneEntity(id: 'a', name: 'A', isCurrent: false, lastAccessTime: now.subtract(const Duration(days: 2))),
        SceneEntity(id: 'b', name: 'B', isCurrent: true, lastAccessTime: now.subtract(const Duration(days: 1))),
        SceneEntity(id: 'c', name: 'C', isCurrent: false, lastAccessTime: now),
      ];

      final manager = StubSceneManager(scenes);
      final bus = EventBus();
      final vm = ScenesViewModel(manager, StubDeviceManager(), bus, null);

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

// a tiny alias so the tests above can construct it without importing a
// full stub definition multiple times
class _StubDeviceManager extends StubDeviceManager {}
