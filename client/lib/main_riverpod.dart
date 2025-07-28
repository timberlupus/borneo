import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app/app_theme.dart';
import 'core/providers/core_providers.dart';
import 'core/services/local_service.dart';
import 'features/settings/providers/settings_providers.dart';
import 'features/settings/views/app_settings_screen_riverpod.dart';
import 'features/my/views/my_screen_riverpod.dart';
import 'features/my/views/about_screen_riverpod.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final sharedPreferences = await SharedPreferences.getInstance();

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(sharedPreferences),
        localeServiceProvider.overrideWithValue(AppLocaleService()),
      ],
      child: const MyAppRiverpod(),
    ),
  );
}

class MyAppRiverpod extends ConsumerWidget {
  const MyAppRiverpod({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final locale = ref.watch(localeProvider);

    // 初始化应用
    ref.watch(appInitializationProvider);

    return MaterialApp(
      title: 'Borneo IoT',
      theme: BorneoTheme(const TextTheme()).light(),
      darkTheme: BorneoTheme(const TextTheme()).dark(),
      themeMode: themeMode,
      locale: locale,
      home: const RiverpodDemoScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

// 演示屏幕，用于测试迁移后的功能
class RiverpodDemoScreen extends ConsumerWidget {
  const RiverpodDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod 迁移测试')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('测试设置屏幕'),
            subtitle: const Text('Settings Screen - Riverpod版本'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AppSettingsScreenRiverpod()));
            },
          ),
          ListTile(
            title: const Text('测试我的屏幕'),
            subtitle: const Text('My Screen - Riverpod版本'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyScreenRiverpod()));
            },
          ),
          ListTile(
            title: const Text('测试关于屏幕'),
            subtitle: const Text('About Screen - Riverpod版本'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreenRiverpod()));
            },
          ),
        ],
      ),
    );
  }
}
