import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/features/devices/view_models/grouped_devices_view_model.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'package:sembast/sembast.dart';
import 'dart:collection';

import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:borneo_app/features/devices/models/device_module_metadata.dart';

// reuse stubs from existing tests (copied locally)
class _StubSceneManager implements ISceneManager {
  bool get isInitialized => true;
  SceneEntity currentScene;
  _StubSceneManager(this.currentScene);
  @override
  SceneEntity get current => currentScene;
  // unused members
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubGroupManager implements IGroupManager {
  @override
  bool get isInitialized => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> create({required String name, String notes = '', Transaction? tx}) async {}
  @override
  Future<void> delete(String id, {Transaction? tx}) async {}
  @override
  Future<DeviceGroupEntity> fetch(String id, {Transaction? tx}) async {
    throw UnimplementedError();
  }
  @override
  Future<List<DeviceGroupEntity>> fetchAllGroupsInCurrentScene({Transaction? tx}) async => [];
  @override
  Future<void> update(String id, {required String name, String notes = '', Transaction? tx}) async {}
}

class _StubDeviceManager implements IDeviceManager {
  @override
  bool get isInitialized => true;
  @override
  // we only need fetchAllDevicesInScene
  Future<List<DeviceEntity>> fetchAllDevicesInScene({String? sceneID}) async => [];
  // stub others
  @override
  EventDispatcher get allDeviceEvents => DefaultEventDispatcher();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _StubDeviceModuleRegistry implements IDeviceModuleRegistry {
  @override
  UnmodifiableMapView<String, DeviceModuleMetadata> get metaModules =>
      UnmodifiableMapView(<String, DeviceModuleMetadata>{});
}
void main() {
  test('SceneUpdatedEvent causes notification when current scene updated', () async {
    final bus = EventBus();
    final scene = SceneEntity(id: 's1', name: 'First', isCurrent: true, lastAccessTime: DateTime.now());
    final sceneMgr = _StubSceneManager(scene);
    final vm = GroupedDevicesViewModel(
      bus,
      sceneMgr,
      _StubGroupManager(),
      _StubDeviceManager(),
      _StubDeviceModuleRegistry(),
      clock: TestClock(),
      gt: _FakeGt(),
    );

    // mark initialized to avoid reload requirement
    // call initialize which will load empty lists
    await vm.initialize();

    var notified = false;
    vm.addListener(() {
      notified = true;
    });

    // update underlying scene object
    final updated = scene.copyWith(name: 'Changed');
    sceneMgr.currentScene = updated;

    bus.fire(SceneUpdatedEvent(updated));
    // allow microtasks
    await Future<void>.delayed(Duration.zero);

    expect(notified, isTrue);
    expect(vm.currentScene.name, 'Changed');
  });
}

// minimal definitions used above
class _FakeGt implements GettextLocalizations {
  @override
  String translate(String key,
          {String? domain,
          String? keyPlural,
          String msgctxt = '',
          Map<String, Object>? nArgs,
          List<Object>? pArgs}) => key;
}

class TestClock implements IClock {
  @override
  DateTime now() => DateTime.now();
  
  @override
  DateTime utcNow() {
    // TODO: implement utcNow
    throw UnimplementedError();
  }
}
