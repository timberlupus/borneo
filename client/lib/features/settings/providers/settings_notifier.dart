import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:event_bus/event_bus.dart';

import '../../../core/services/local_service.dart';
import '../../../core/events/app_events.dart';

const kBrightnessKey = "app.brightness";
const kLocaleKey = "app.locale";

class SettingsState {
  final ThemeMode themeMode;
  final Locale? locale;
  final String temperatureUnit;
  final bool isLoading;

  const SettingsState({
    this.themeMode = ThemeMode.system,
    this.locale,
    this.temperatureUnit = 'C',
    this.isLoading = true,
  });

  SettingsState copyWith({ThemeMode? themeMode, Locale? locale, String? temperatureUnit, bool? isLoading}) {
    return SettingsState(
      themeMode: themeMode ?? this.themeMode,
      locale: locale ?? this.locale,
      temperatureUnit: temperatureUnit ?? this.temperatureUnit,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class SettingsNotifier extends StateNotifier<SettingsState> {
  SettingsNotifier({required this.localeService, required this.sharedPreferences, required this.eventBus})
    : super(const SettingsState());

  final LocaleService localeService;
  final SharedPreferences sharedPreferences;
  final EventBus eventBus;

  static const _kBrightnessKey = kBrightnessKey;
  static const _kLocaleKey = kLocaleKey;

  Future<void> initialize() async {
    try {
      // 主题设置
      final idx = sharedPreferences.getInt(_kBrightnessKey);
      ThemeMode themeMode;

      if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
        themeMode = ThemeMode.values[idx];
      } else {
        final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
        if (platformBrightness == Brightness.dark) {
          themeMode = ThemeMode.dark;
          await sharedPreferences.setInt(_kBrightnessKey, ThemeMode.dark.index);
        } else {
          themeMode = ThemeMode.light;
          await sharedPreferences.setInt(_kBrightnessKey, ThemeMode.light.index);
        }
      }

      // 语言设置
      Locale? locale;
      final localeStr = sharedPreferences.getString(_kLocaleKey);
      if (localeStr != null) {
        if (localeStr == 'en_US') {
          locale = const Locale('en', 'US');
        } else if (localeStr == 'zh_CN') {
          locale = const Locale('zh', 'CN');
        }
      } else {
        final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
        if (sysLocale.languageCode == 'zh') {
          locale = const Locale('zh', 'CN');
          await sharedPreferences.setString(_kLocaleKey, 'zh_CN');
        } else {
          locale = const Locale('en', 'US');
          await sharedPreferences.setString(_kLocaleKey, 'en_US');
        }
      }

      final temperatureUnit = localeService.temperatureUnit;

      state = state.copyWith(themeMode: themeMode, locale: locale, temperatureUnit: temperatureUnit, isLoading: false);
    } catch (e) {
      state = state.copyWith(isLoading: false);
      rethrow;
    }
  }

  Future<void> changeBrightness(ThemeMode mode) async {
    await sharedPreferences.setInt(_kBrightnessKey, mode.index);
    state = state.copyWith(themeMode: mode);
    eventBus.fire(ThemeChangedEvent(mode));
  }

  Future<void> changeLocale(Locale locale) async {
    final localeStr = locale.languageCode == 'zh' ? 'zh_CN' : 'en_US';
    await sharedPreferences.setString(_kLocaleKey, localeStr);
    state = state.copyWith(locale: locale);
    eventBus.fire(AppLocaleChangedEvent(locale));
  }

  Future<void> changeTemperatureUnit(String unit) async {
    await localeService.setTemperatureUnit(unit);
    state = state.copyWith(temperatureUnit: unit);
  }
}
