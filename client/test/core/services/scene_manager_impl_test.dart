import 'dart:io';

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
  var databaseId = 0;

  group('SceneManagerImpl', () {
    late SceneManagerImpl manager;
    late EventBus bus;
    late StubBlobManager blobManager;

    setUp(() async {
      final db = await databaseFactoryMemory.openDatabase('test-${databaseId++}.db');
      bus = EventBus();
      blobManager = StubBlobManager();
      manager = SceneManagerImpl(FakeGettext(), db, bus, blobManager, clock: TestClock());
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

      final imageFile = await _createTempImageFile('updated-image');
      addTearDown(() async => imageFile.parent.delete(recursive: true));

      final result = await manager.update(id: orig.id, name: updatedName, notes: orig.notes, imagePath: imageFile.path);
      final persisted = await manager.single(orig.id);

      expect(result.name, equals(updatedName));
      expect(manager.current.name, equals(updatedName));
      expect(persisted.imageID, equals('fake-blob-2'));
      expect(persisted.imagePath, equals('fake-blob-2'));
      expect(blobManager.createdBlobIDs.last, equals('fake-blob-2'));
      expect(events, hasLength(1));
      expect(events.first.scene.id, equals(orig.id));
    });

    test('create imports selected image into blob storage', () async {
      final imageFile = await _createTempImageFile('scene-image');
      addTearDown(() async => imageFile.parent.delete(recursive: true));

      final created = await manager.create(name: 'Custom', notes: 'n', imagePath: imageFile.path);

      expect(created.imageID, equals('fake-blob-2'));
      expect(created.imagePath, equals('fake-blob-2'));
      expect(blobManager.createdBlobIDs.last, equals('fake-blob-2'));
      expect(blobManager.createdBlobSizes.last, equals('scene-image'.length));
    });

    test('update removes previous blob when replacing image', () async {
      final firstImage = await _createTempImageFile('first-image');
      final secondImage = await _createTempImageFile('second-image');
      addTearDown(() async => firstImage.parent.delete(recursive: true));
      addTearDown(() async => secondImage.parent.delete(recursive: true));

      final created = await manager.create(name: 'Custom', notes: 'n', imagePath: firstImage.path);
      final updated = await manager.update(
        id: created.id,
        name: created.name,
        notes: created.notes,
        imagePath: secondImage.path,
      );
      final persisted = await manager.single(created.id);

      expect(created.imageID, equals('fake-blob-2'));
      expect(updated.imageID, equals('fake-blob-3'));
      expect(persisted.imageID, equals('fake-blob-3'));
      expect(persisted.imagePath, equals('fake-blob-3'));
      expect(blobManager.deletedBlobIDs, contains('fake-blob-2'));
    });

    test('update removes previous blob when clearing image', () async {
      final imageFile = await _createTempImageFile('clear-image');
      addTearDown(() async => imageFile.parent.delete(recursive: true));

      final created = await manager.create(name: 'Custom', notes: 'n', imagePath: imageFile.path);
      final updated = await manager.update(id: created.id, name: created.name, notes: created.notes, imagePath: null);
      final persisted = await manager.single(created.id);

      expect(created.imageID, equals('fake-blob-2'));
      expect(updated.imageID, isNull);
      expect(persisted.imageID, isNull);
      expect(persisted.imagePath, isNull);
      expect(blobManager.deletedBlobIDs, contains('fake-blob-2'));
    });

    test('initialize restores image path from image id on next launch', () async {
      final db = await databaseFactoryMemory.openDatabase('rehydrate-${databaseId++}.db');
      final firstBus = EventBus();
      final firstBlobManager = PrefixBlobManager('/container-a');
      final firstManager = SceneManagerImpl(FakeGettext(), db, firstBus, firstBlobManager, clock: TestClock());
      await firstManager.initialize(StubGroupManager(), StubDeviceManager());

      final created = await firstManager.create(name: 'Custom', notes: 'n', imagePath: null);
      expect(created.imagePath, isNull);

      final imageFile = await _createTempImageFile('rehydrate-image');
      addTearDown(() async => imageFile.parent.delete(recursive: true));

      final updatedWithImage = await firstManager.update(
        id: created.id,
        name: created.name,
        notes: created.notes,
        imagePath: imageFile.path,
      );
      expect(updatedWithImage.imageID, equals('fake-blob-2'));

      final secondBus = EventBus();
      final secondBlobManager = PrefixBlobManager('/container-b');
      final secondManager = SceneManagerImpl(FakeGettext(), db, secondBus, secondBlobManager, clock: TestClock());
      await secondManager.initialize(StubGroupManager(), StubDeviceManager());

      final reloaded = await secondManager.single(created.id);
      expect(reloaded.imageID, equals('fake-blob-2'));
      expect(reloaded.imagePath, equals('/container-b/fake-blob-2'));
    });
  });
}

Future<File> _createTempImageFile(String contents) async {
  final tempDir = await Directory.systemTemp.createTemp('scene-manager-test');
  final file = File('${tempDir.path}${Platform.pathSeparator}image.bin');
  await file.writeAsString(contents);
  return file;
}

class PrefixBlobManager extends StubBlobManager {
  PrefixBlobManager(this.prefix);

  final String prefix;

  @override
  String getPath(String blobID) => '$prefix/$blobID';
}
