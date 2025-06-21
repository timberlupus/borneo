import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sembast/sembast.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';
import 'package:borneo_app/core/services/blob_manager.dart';

/// 基础依赖 Providers
/// 这些需要在应用根部通过 override 提供实际实例

final databaseProvider = Provider<Database>((ref) {
  throw UnimplementedError('Database provider must be overridden in main.dart');
});

final loggerProvider = Provider<Logger>((ref) {
  throw UnimplementedError('Logger provider must be overridden in main.dart');
});

final eventBusProvider = Provider<EventBus>((ref) {
  throw UnimplementedError('EventBus provider must be overridden in main.dart');
});

final blobManagerProvider = Provider<IBlobManager>((ref) {
  throw UnimplementedError('BlobManager provider must be overridden in main.dart');
});

/// Gettext Localizations Provider
/// 这个比较特殊，因为它依赖于 BuildContext
/// 在完全迁移之前，可能需要通过其他方式获取
final gettextProvider = Provider<dynamic>((ref) {
  throw UnimplementedError('GettextLocalizations needs special handling');
});
