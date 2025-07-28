import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

// 核心服务Provider
final eventBusProvider = Provider<EventBus>((ref) {
  return EventBus();
});

final loggerProvider = Provider<Logger>((ref) {
  return Logger();
});

// 全局初始化Provider
final appInitializationProvider = FutureProvider<void>((ref) async {
  // 初始化Settings - 需要导入相关模块
  // 注意：这里需要确保settings_notifier.dart被正确导入
  // 为了避免循环依赖，我们暂时不在这里初始化
});
