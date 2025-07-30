/*
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

class RiverpodDemoScreen extends ConsumerWidget {
  const RiverpodDemoScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Riverpod Migration Demo')),
      body: ListView(
        children: [
          ListTile(
            title: const Text('Test Settings Screen'),
            subtitle: const Text('Settings Screen - Riverpod Version'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AppSettingsScreenRiverpod()));
            },
          ),
          ListTile(
            title: const Text('Test My Screen'),
            subtitle: const Text('My Screen - Riverpod Version'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const MyScreenRiverpod()));
            },
          ),
          ListTile(
            title: const Text('Test About Screen'),
            subtitle: const Text('About Screen - Riverpod Version'),
            onTap: () {
              Navigator.push(context, MaterialPageRoute(builder: (context) => const AboutScreenRiverpod()));
            },
          ),
        ],
      ),
    );
  }
}
*/