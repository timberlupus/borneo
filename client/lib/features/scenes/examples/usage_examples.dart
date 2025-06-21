import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:provider/provider.dart' as provider;

import '../views/scene_edit_screen.dart';
import '../providers/scene_edit_provider.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

/// 如何在路由中使用新的 Riverpod 版本
///
/// 1. 在应用根部包装 ProviderScope（如果还没有的话）
/// 2. 使用新的 SceneEditScreenSimple 替代原来的 SceneEditScreen
///
/// 示例用法：
class SceneEditRouteExample {
  static Route<dynamic> createRoute(SceneEditArguments args) {
    return MaterialPageRoute(builder: (context) => SceneEditScreen(args: args));
  }
}

/// 如果需要在应用根部添加 ProviderScope
/// 在 main.dart 中这样修改：
///
/// runApp(
///   ProviderScope(  // 添加这个
///     child: MultiProvider(
///       providers: [...],
///       child: BorneoApp(),
///     ),
///   ),
/// );

/// 比较：原来的使用方式 vs 新的使用方式

// 原来的方式：
class OldUsageExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return provider.ChangeNotifierProvider<vm.SceneEditViewModel>(
      create: (context) => vm.SceneEditViewModel(
        context.read<SceneManager>(),
        isCreation: true,
        globalEventBus: context.read<EventBus>(),
        logger: context.read<Logger>(),
      ),
      builder: (context, child) => SceneEditScreen(args: vm.SceneEditArguments(isCreation: true)),
    );
  }
}

// 新的方式：
class NewUsageExample extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // 更简单！不需要手动创建 ViewModel
    return SceneEditScreen(args: SceneEditArguments(isCreation: true));
  }
}

/// 测试友好性示例

// 原来的测试需要复杂的设置：
/*
testWidgets('SceneEdit should work', (tester) async {
  await tester.pumpWidget(
    MultiProvider(
      providers: [
        Provider<SceneManager>(create: (_) => MockSceneManager()),
        Provider<EventBus>(create: (_) => EventBus()),
        Provider<Logger>(create: (_) => MockLogger()),
      ],
      child: MaterialApp(
        home: ChangeNotifierProvider<SceneEditViewModel>(
          create: (context) => SceneEditViewModel(...),
          child: SceneEditScreen(...),
        ),
      ),
    ),
  );
});
*/

// 新的测试更简单：
/*
testWidgets('SceneEdit should work', (tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // 可以轻松 mock providers
      ],
      child: MaterialApp(
        home: SceneEditScreenSimple(args: SceneEditArguments(isCreation: true)),
      ),
    ),
  );
});
*/
