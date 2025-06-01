import 'package:borneo_app/view_models/abstract_screen_view_model.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../events.dart';

const kBrightnessKey = "app.brightness";
const kLocaleKey = "app.locale";

class AppSettingsViewModel extends AbstractScreenViewModel {
  AppSettingsViewModel({required super.globalEventBus, super.logger});

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  Locale? _locale;
  Locale? get locale => _locale;

  static const _kBrightnessKey = kBrightnessKey;
  static const _kLocaleKey = kLocaleKey;

  @override
  Future<void> onInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kBrightnessKey);
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[idx];
    } else {
      _themeMode = ThemeMode.system;
    }
    final localeStr = prefs.getString(_kLocaleKey);
    if (localeStr != null) {
      if (localeStr == 'en_US') {
        _locale = const Locale('en', 'US');
      } else if (localeStr == 'zh_CN') {
        _locale = const Locale('zh', 'CN');
      }
    }
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
    final localeStr = locale.languageCode == 'zh' ? 'zh_CN' : 'en_US';
    await prefs.setString(_kLocaleKey, localeStr);
    notifyListeners();
    globalEventBus.fire(AppLocaleChangedEvent(locale));
  }
}
