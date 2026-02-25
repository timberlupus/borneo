import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/services/scene_manager_impl.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:sembast/sembast_memory.dart';

import '../../mocks/mocks.dart';

void main() {
  // some tests in this file access asset bundles via ServicesBinding; ensure
  // the binding is initialized before any code runs.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SceneManagerImpl', () {
    late SceneManagerImpl manager;
    late EventBus bus;

    setUp(() async {
      final db = await databaseFactoryMemory.openDatabase('test.db');
      bus = EventBus();
      manager = SceneManagerImpl(FakeGettext(), db, bus, StubBlobManager(), clock: TestClock());
      await manager.initialize(StubGroupManager(), StubDeviceManager());
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
