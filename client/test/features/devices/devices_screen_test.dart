import 'dart:collection';

import 'package:borneo_app/features/devices/views/devices_screen.dart';
import 'package:borneo_app/features/devices/view_models/grouped_devices_view_model.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/features/devices/models/device_module_metadata.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/core/services/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:provider/provider.dart';
import 'package:sembast/sembast.dart';

class _StubSceneManager implements ISceneManager {
  bool get isInitialized => true;
  SceneEntity currentScene;
  _StubSceneManager(this.currentScene);
  @override
  SceneEntity get current => currentScene;
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
  Future<List<DeviceEntity>> fetchAllDevicesInScene({String? sceneID}) async => [];
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

void main() {
  testWidgets('AppBar title updates when scene name changes', (WidgetTester tester) async {
    final bus = EventBus();
    final scene = SceneEntity(id: 's1', name: 'Initial', isCurrent: true, lastAccessTime: DateTime.now());
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

    await vm.initialize();

    await tester.pumpWidget(
      MaterialApp(
        home: ChangeNotifierProvider<GroupedDevicesViewModel>.value(
          value: vm,
          child: DevicesScreen(),
        ),
      ),
    );

    // initial title should reflect "Initial"
    expect(find.textContaining('Initial'), findsOneWidget);

    // modify scene name and fire event
    sceneMgr.currentScene = scene.copyWith(name: 'Updated');
    bus.fire(SceneUpdatedEvent(sceneMgr.currentScene));
    await tester.pump();

    expect(find.textContaining('Updated'), findsOneWidget);
  });
}
