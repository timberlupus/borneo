import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_bus/event_bus.dart';

import '../../../core/services/local_service.dart';
import '../../../core/events/app_events.dart';

const kBrightnessKey = "app.brightness";
const kLocaleKey = "app.locale";

/// ChangeNotifier version of SettingsNotifier
class SettingsViewModel extends ChangeNotifier {
  final ILocaleService _localeService;
  final SharedPreferences _sharedPreferences;
  final EventBus _eventBus;

  SettingsViewModel({
    required ILocaleService localeService,
    required SharedPreferences sharedPreferences,
    required EventBus eventBus,
  }) : _localeService = localeService,
       _sharedPreferences = sharedPreferences,
       _eventBus = eventBus {
    initialize();
  }

  ThemeMode _themeMode = ThemeMode.system;
  Locale? _locale;
  String _temperatureUnit = 'C';
  bool _isLoading = true;

  ThemeMode get themeMode => _themeMode;
  Locale? get locale => _locale;
  String get temperatureUnit => _temperatureUnit;
  bool get isLoading => _isLoading;

  Future<void> initialize() async {
    _isLoading = true;
    notifyListeners();
    try {
      await _loadThemeMode();
      await _loadLocale();
      _temperatureUnit = _localeService.temperatureUnit;
    } catch (_) {
      // swallow - keep defaults
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> _loadThemeMode() async {
    final idx = _sharedPreferences.getInt(kBrightnessKey);
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[idx];
      return;
    }
    final platformBrightness = WidgetsBinding.instance.platformDispatcher.platformBrightness;
    if (platformBrightness == Brightness.dark) {
      _themeMode = ThemeMode.dark;
      await _sharedPreferences.setInt(kBrightnessKey, ThemeMode.dark.index);
    } else {
      _themeMode = ThemeMode.light;
      await _sharedPreferences.setInt(kBrightnessKey, ThemeMode.light.index);
    }
  }

  Future<void> _loadLocale() async {
    final localeStr = _sharedPreferences.getString(kLocaleKey);
    if (localeStr != null) {
      if (localeStr == 'en_US') {
        _locale = const Locale('en', 'US');
      } else if (localeStr == 'zh_CN') {
        _locale = const Locale('zh', 'CN');
      } else if (localeStr == 'es') {
        _locale = const Locale('es');
      }
      return;
    }
    final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
    if (sysLocale.languageCode == 'zh') {
      _locale = const Locale('zh', 'CN');
      await _sharedPreferences.setString(kLocaleKey, 'zh_CN');
    } else {
      _locale = const Locale('en', 'US');
      await _sharedPreferences.setString(kLocaleKey, 'en_US');
    }
  }

  Future<void> changeBrightness(ThemeMode mode) async {
    _themeMode = mode;
    await _sharedPreferences.setInt(kBrightnessKey, mode.index);
    _eventBus.fire(ThemeChangedEvent(mode));
    notifyListeners();
  }

  Future<void> changeLocale(Locale locale) async {
    _locale = locale;
    final localeStr = locale.languageCode == 'zh' ? 'zh_CN' : 'en_US';
    await _sharedPreferences.setString(kLocaleKey, localeStr);
    _eventBus.fire(AppLocaleChangedEvent(locale));
    notifyListeners();
  }

  Future<void> changeTemperatureUnit(String unit) async {
    await _localeService.setTemperatureUnit(unit);
    _temperatureUnit = unit;
    notifyListeners();
  }
}
