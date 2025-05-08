import 'dart:io';
import 'dart:typed_data';

import 'package:borneo_app/models/base_entity.dart';
import 'package:logger/logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

abstract class IBlobManager {
  bool get isInitialized;
  String get blobsDir;
  Future<void> initialize();
  String getPath(String blobID);
  Future<File> open(String blobID);
  Future<String> create(ByteData bytes);
  Future<void> delete(String blobID);
  Future<void> clear();
}

class FlutterAppBlobManager implements IBlobManager {
  final Logger? logger;

  bool _isInitialized = false;
  @override
  bool get isInitialized => _isInitialized;

  late final String _blobsDir;

  @override
  String get blobsDir => _blobsDir;

  FlutterAppBlobManager({this.logger});

  @override
  Future<void> initialize() async {
    if (_isInitialized) {
      return;
    }
    logger?.i('Start to initialize BlobManager...');
    final appDir = await getApplicationDocumentsDirectory();
    await appDir.create(recursive: true);

    final blobsDir = Directory(path.join(appDir.path, 'blobs'));
    await blobsDir.create(recursive: true);
    _blobsDir = blobsDir.path;

    _isInitialized = true;
    logger?.i('BlobManager has been initialized.');
  }

  @override
  String getPath(String blobID) {
    final hashDirName = _makeHashDirName(blobID);
    return path.join(hashDirName, blobID);
  }

  @override
  Future<File> open(String blobID) async {
    final hashDirPath = _makeHashDirName(blobID);
    await Directory(hashDirPath).create(recursive: true);
    final filePath = path.join(hashDirPath, blobID);
    return File(filePath);
  }

  @override
  Future<String> create(ByteData bytes) async {
    final id = BaseEntity.generateID();
    final file = await open(id);
    final bytesList = bytes.buffer.asUint8List(bytes.offsetInBytes, bytes.lengthInBytes);
    await file.writeAsBytes(bytesList);
    return id;
  }

  @override
  Future<void> delete(String blobID) async {
    final hashDirPath = _makeHashDirName(blobID);
    final filePath = path.join(hashDirPath, blobID);
    await File(filePath).delete(recursive: false);
    logger?.i('Deleted blob file: `$filePath`');
  }

  @override
  Future<void> clear() async {
    _deleteFilesInDirectory(Directory(_blobsDir));
  }

  String _makeHashDirName(String blobID) => path.join(_blobsDir, blobID.hashCode.toRadixString(16).padLeft(2, '0'));

  Future<void> _deleteFilesInDirectory(Directory directory) async {
    Stream<FileSystemEntity> entities = directory.list(recursive: true, followLinks: false);

    await for (FileSystemEntity entity in entities) {
      if (entity is File) {
        logger?.i('Deleted blob file: `${entity.path}`');
        await entity.delete();
      } else if (entity is Directory) {
        await _deleteFilesInDirectory(entity);
      }
    }
  }
}
