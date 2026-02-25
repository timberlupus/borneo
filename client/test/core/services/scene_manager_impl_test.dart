import 'dart:io';
import 'dart:typed_data';

import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/services/blob_manager.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/scene_manager_impl.dart';
import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_kernel_abstractions/event_dispatcher.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:lw_wot/thing.dart';
import 'package:sembast/sembast_memory.dart';

// minimal fake implementations used by SceneManagerImpl
class _FakeGettextLocalizations implements GettextLocalizations {
  @override
  String translate(
    String key, {
    String? domain,
    String? keyPlural,
    String msgctxt = '',
    Map<String, Object>? nArgs,
    List<Object>? pArgs,
  }) => key;
}

class _StubBlobManager implements IBlobManager {
  bool _inited = false;
  @override
  bool get isInitialized => _inited;
  @override
  String get blobsDir => '';
  @override
  Future<void> initialize() async => _inited = true;
  @override
  String getPath(String blobID) => blobID;
  @override
  Future<File> open(String blobID) async => throw UnimplementedError();
  @override
  Future<String> create(ByteData bytes) async => 'fake-blob';
  @override
  Future<void> delete(String blobID) async {}
  @override
  Future<void> clear() async {}
}

// minimal stubs for the dependencies of initialize()
class _StubGroupManager implements IGroupManager {
  @override
  bool get isInitialized => true;
  @override
  Future<void> initialize() async {}
  @override
  Future<void> create({required String name, String notes = '', Transaction? tx}) async {}
  @override
  Future<void> update(String id, {required String name, String notes = '', Transaction? tx}) async {}
  @override
  Future<void> delete(String id, {Transaction? tx}) async {}
  @override
  Future<DeviceGroupEntity> fetch(String id, {Transaction? tx}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<DeviceGroupEntity>> fetchAllGroupsInCurrentScene({Transaction? tx}) async => [];
}

class _StubDeviceManager implements IDeviceManager {
  @override
  bool get isInitialized => true;
  @override
  EventDispatcher get allDeviceEvents => DefaultEventDispatcher();
  @override
  Iterable<BoundDevice> get boundDevices => const [];
  @override
  Iterable<WotThing> get wotThingsInCurrentScene => const [];
  @override
  bool get isDiscoverying => false;
  // implement only initialize signature used above
  @override
  Future<void> initialize({CancellationToken? cancelToken}) async {}
  @override
  Future<List<DeviceEntity>> fetchAllDevicesInScene({String? sceneID}) async => [];
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('SceneManagerImpl', () {
    late SceneManagerImpl manager;
    late EventBus bus;

    setUp(() async {
      final db = await databaseFactoryMemory.openDatabase('test.db');
      bus = EventBus();
      manager = SceneManagerImpl(_FakeGettextLocalizations(), db, bus, _StubBlobManager(), clock: TestClock());
      await manager.initialize(_StubGroupManager(), _StubDeviceManager());
    });

    test('initialize sets current to a default scene', () {
      expect(manager.current, isNotNull);
      expect(manager.current.name, isNotEmpty);
    });

    test('update modifies current and fires SceneUpdatedEvent', () async {
      final orig = manager.current;
      final updatedName = '${orig.name}-changed';
      final events = <SceneUpdatedEvent>[];
      bus.on<SceneUpdatedEvent>().listen(events.add);

      final result = await manager.update(id: orig.id, name: updatedName, notes: orig.notes, imagePath: 'new-path');

      expect(result.name, equals(updatedName));
      expect(manager.current.name, equals(updatedName));
      expect(manager.current.imagePath, equals('new-path'));
      expect(events, hasLength(1));
      expect(events.first.scene.id, equals(orig.id));
    });
  });
}

// simple clock implementation for tests
class TestClock implements IClock {
  @override
  DateTime now() => DateTime.now();

  @override
  DateTime utcNow() => DateTime.now().toUtc();
}
