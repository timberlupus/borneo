import 'package:borneo_app/core/services/db.dart';
import 'package:borneo_common/exceptions.dart';

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DBProvider Tests', () {
    final testDir = './app_test';
    late DBProvider db;

    setUp(() async {
      db = DBProvider(testDir);
      // 清理旧文件
      final dbFile = File('$testDir/borneo.db');
      if (await dbFile.exists()) {
        await dbFile.delete();
      }
    });

    test('Should not be initialized before initialize()', () {
      expect(db.isInitialized, false);
    });

    test('Should be initialized after initialize()', () async {
      await db.initialize();
      expect(db.isInitialized, true);
    });

    test('isExisted returns false before initialize', () async {
      final existed = await db.isExisted();
      expect(existed, false);
    });

    test('isExisted returns true after initialize', () async {
      await db.initialize();
      final dbFile = File(db.dbPath);
      await dbFile.create(recursive: true);
      final existed = await db.isExisted();
      expect(existed, true);
    });

    test('open throws if not initialized', () async {
      expect(() => db.open(), throwsA(isA<InvalidOperationException>()));
    });

    test('delete throws if not initialized', () async {
      expect(() => db.delete(), throwsA(isA<InvalidOperationException>()));
    });

    test('delete throws if file not exists', () async {
      await db.initialize();
      expect(() => db.delete(), throwsA(isA<FileNotFoundException>()));
    });

    test('delete removes the db file', () async {
      await db.initialize();
      final dbFile = File(db.dbPath);
      await dbFile.create(recursive: true);
      expect(await dbFile.exists(), true);
      await db.delete();
      expect(await dbFile.exists(), false);
    });
  });
}
