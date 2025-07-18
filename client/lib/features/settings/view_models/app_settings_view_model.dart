import 'package:borneo_app/shared/view_models/abstract_screen_view_model.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/events/app_events.dart';
import 'package:borneo_app/core/services/local_service.dart';

const kBrightnessKey = "app.brightness";
const kLocaleKey = "app.locale";

class AppSettingsViewModel extends AbstractScreenViewModel {
  AppSettingsViewModel({required super.globalEventBus, required super.logger, required this.localeService});

  final LocaleService localeService;

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
    // 主题
    final idx = prefs.getInt(_kBrightnessKey);
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[idx];
    } else {
      // 获取系统主题
      final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
      if (platformBrightness == Brightness.dark) {
        _themeMode = ThemeMode.dark;
        await prefs.setInt(_kBrightnessKey, ThemeMode.dark.index);
      } else {
        _themeMode = ThemeMode.light;
        await prefs.setInt(_kBrightnessKey, ThemeMode.light.index);
      }
    }
    // 语言
    final localeStr = prefs.getString(_kLocaleKey);
    if (localeStr != null) {
      if (localeStr == 'en_US') {
        _locale = const Locale('en', 'US');
      } else if (localeStr == 'zh_CN') {
        _locale = const Locale('zh', 'CN');
      }
    } else {
      final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
      if (sysLocale.languageCode == 'zh') {
        _locale = const Locale('zh', 'CN');
        await prefs.setString(_kLocaleKey, 'zh_CN');
      } else {
        _locale = const Locale('en', 'US');
        await prefs.setString(_kLocaleKey, 'en_US');
      }
    }
    // 温度单位无需再在此初始化，由 LocaleService 负责
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

  Future<void> changeTemperatureUnit(String unit) async {
    await localeService.setTemperatureUnit(unit);
    notifyListeners();
  }
}
