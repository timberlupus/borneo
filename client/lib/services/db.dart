import 'dart:io';

import 'package:borneo_app/services/store_names.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:path/path.dart' as path;
import 'package:sembast/sembast_io.dart';

class DBProvider {
  final String appDir;
  late final String dbPath;

  bool _isInitialized = false;

  bool get isInitialized => _isInitialized;

  DBProvider(this.appDir);

  Future<void> initialize() async {
    // get the application documents directory
    // make sure it exists
    // build the database path
    dbPath = path.join(appDir, 'borneo.db');

    _isInitialized = true;
  }

  void _ensureInit() {
    if (!_isInitialized) {
      throw InvalidOperationException(message: "DB uninitialized!");
    }
  }

  Future<void> delete() async {
    _ensureInit();

    final file = File(dbPath);
    if (await file.exists()) {
      await file.delete();
    } else {
      throw FileNotFoundException(dbPath);
    }
  }

  Future<bool> isExisted() => File(dbPath).exists();

  Future<Database> open() async {
    _ensureInit();
    return await databaseFactoryIo.openDatabase(dbPath);
  }
}

extension DatabaseExtension on Database {
  StoreRef<String, dynamic> makeAppStatusStore() => StoreRef<String, dynamic>(StoreNames.appStatus);
}
