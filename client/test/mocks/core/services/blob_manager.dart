import 'dart:io';
import 'dart:typed_data';

import 'package:borneo_app/core/services/blob_manager.dart';

/// Lightweight fake used by scene_manager_impl tests.
class StubBlobManager implements IBlobManager {
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

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
