import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/services/local_service.dart';
import '../../../core/providers/core_providers.dart';
import 'settings_notifier.dart';

// 基础服务Provider
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError('SharedPreferences must be overridden in main.dart');
});

final localeServiceProvider = Provider<LocaleService>((ref) {
  throw UnimplementedError('LocaleService must be overridden in main.dart');
});

// Settings Provider
final settingsNotifierProvider = StateNotifierProvider<SettingsNotifier, SettingsState>((ref) {
  return SettingsNotifier(
    localeService: ref.watch(localeServiceProvider),
    sharedPreferences: ref.watch(sharedPreferencesProvider),
    eventBus: ref.read(eventBusProvider),
  );
});

// 便捷Provider
final themeModeProvider = Provider<ThemeMode>((ref) {
  return ref.watch(settingsNotifierProvider).themeMode;
});

final localeProvider = Provider<Locale?>((ref) {
  return ref.watch(settingsNotifierProvider).locale;
});

final temperatureUnitProvider = Provider<String>((ref) {
  return ref.watch(settingsNotifierProvider).temperatureUnit;
});

final settingsLoadingProvider = Provider<bool>((ref) {
  return ref.watch(settingsNotifierProvider).isLoading;
});
