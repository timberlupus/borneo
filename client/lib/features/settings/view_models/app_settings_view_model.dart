import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/events/app_events.dart';
import 'package:borneo_app/core/services/local_service.dart';
import 'package:borneo_app/core/config/language_config.dart';

const kBrightnessKey = "app.brightness";
const kLocaleKey = "app.locale";

class AppSettingsViewModel extends AbstractScreenViewModel {
  AppSettingsViewModel({
    required super.globalEventBus,
    required super.logger,
    required this.localeService,
    required super.gt,
  });

  final ILocaleService localeService;

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Locale? _locale;
  Locale? get locale => _locale;

  static const _kBrightnessKey = kBrightnessKey;
  static const _kLocaleKey = kLocaleKey;

  String get temperatureUnit => localeService.temperatureUnit;

  @override
  Future<void> onInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    // Theme
    final idx = prefs.getInt(_kBrightnessKey);
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[idx];
    } else {
      // Get system theme
      final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (platformBrightness == Brightness.dark) {
        _themeMode = ThemeMode.dark;
        await prefs.setInt(_kBrightnessKey, ThemeMode.dark.index);
      } else {
        _themeMode = ThemeMode.light;
        await prefs.setInt(_kBrightnessKey, ThemeMode.light.index);
      }
    }
    // Language
    final localeStr = prefs.getString(_kLocaleKey);
    _locale = LanguageConfig.languageCodeToLocale(localeStr);

    // If first time use, automatically save default language
    if (localeStr == null) {
      final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
      final defaultCode = LanguageConfig.getDefaultLanguageCode(sysLocale);
      await prefs.setString(_kLocaleKey, defaultCode);
    }
    // Temperature unit doesn't need to be initialized here, managed by LocaleService
    notifyListeners();
  }

  Future<void> changeBrightness(ThemeMode mode) async {
    _themeMode = mode;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_kBrightnessKey, mode.index);
    notifyListeners();
    // Fire global theme change event
    globalEventBus.fire(ThemeChangedEvent(mode));
  }

  Future<void> changeLocale(Locale locale) async {
    _locale = locale;
    final prefs = await SharedPreferences.getInstance();
    final localeStr = LanguageConfig.localeToLanguageCode(locale);
    await prefs.setString(_kLocaleKey, localeStr);
    notifyListeners();
    globalEventBus.fire(AppLocaleChangedEvent(locale));
  }

  Future<void> changeTemperatureUnit(String unit) async {
    await localeService.setTemperatureUnit(unit);
    notifyListeners();
  }
}
