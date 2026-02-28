import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/language_config.dart';
import '../../../core/providers.dart';
import '../../../core/events/app_events.dart';

// reuse the same keys that were defined in the old ChangeNotifier-based view
const _kBrightnessKey = "app.brightness";
const _kLocaleKey = "app.locale";

@immutable
class AppSettingsState {
  final ThemeMode themeMode;
  final Locale? locale;
  final String temperatureUnit;

  const AppSettingsState({required this.themeMode, this.locale, required this.temperatureUnit});

  AppSettingsState copyWith({ThemeMode? themeMode, Locale? locale, String? temperatureUnit}) {
    return AppSettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
    );
  }
}

/// Riverpod provider for the settings page.  We use an [AsyncNotifier]
/// so that the screen can react to the asynchronous initialization that
/// previously took place in `onInitialize()`.
final appSettingsProvider = AsyncNotifierProvider<AppSettingsNotifier, AppSettingsState>(
  () => AppSettingsNotifier(),
  name: 'AppSettingsProvider',
);

class AppSettingsNotifier extends AsyncNotifier<AppSettingsState> {
  @override
  Future<AppSettingsState> build() async {
    // pull in the dependencies from the global service providers
    final prefs = ref.read(sharedPreferencesProvider);

    // theme
    ThemeMode themeMode;
    final idx = prefs.getInt(_kBrightnessKey);
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      themeMode = ThemeMode.values[idx];
    } else {
      // no value saved yet; default to system brightness and persist it
      final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (platformBrightness == Brightness.dark) {
        themeMode = ThemeMode.dark;
        await prefs.setInt(_kBrightnessKey, ThemeMode.dark.index);
      } else {
        themeMode = ThemeMode.light;
        await prefs.setInt(_kBrightnessKey, ThemeMode.light.index);
      }
    }

    // language
    final localeStr = prefs.getString(_kLocaleKey);
    Locale? locale = LanguageConfig.languageCodeToLocale(localeStr);
    if (localeStr == null) {
      final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final defaultCode = LanguageConfig.getDefaultLanguageCode(sysLocale);
      await prefs.setString(_kLocaleKey, defaultCode);
      locale = LanguageConfig.languageCodeToLocale(defaultCode);
    }

    // temperature unit comes from the locale service
    final tempUnit = ref.read(localeServiceProvider).temperatureUnit;

    return AppSettingsState(themeMode: themeMode, locale: locale, temperatureUnit: tempUnit);
  }

  Future<void> changeBrightness(ThemeMode mode) async {
    // persist and fire event, then update state; we do not bother
    // setting a loading state since the UI is already showing the
    // previous values and the operations are fast.
    final prefs = ref.read(sharedPreferencesProvider);
    await prefs.setInt(_kBrightnessKey, mode.index);
    ref.read(eventBusProvider).fire(ThemeChangedEvent(mode));

    final current = state.value!;
    state = AsyncValue.data(current.copyWith(themeMode: mode));
  }

  Future<void> changeLocale(Locale locale) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final localeStr = LanguageConfig.localeToLanguageCode(locale);
    await prefs.setString(_kLocaleKey, localeStr);
    ref.read(eventBusProvider).fire(AppLocaleChangedEvent(locale));

    final current = state.value!;
    state = AsyncValue.data(current.copyWith(locale: locale));
  }

  Future<void> changeTemperatureUnit(String unit) async {
    await ref.read(localeServiceProvider).setTemperatureUnit(unit);
    final current = state.value!;
    state = AsyncValue.data(current.copyWith(temperatureUnit: unit));
  }
}
