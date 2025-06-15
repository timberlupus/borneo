import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/widgets.dart';

abstract class LocaleService {
  Future<void> initialize();
  String get temperatureUnitText;
  double convertTemperatureValue(double celsius);
  String get temperatureUnit;
  Future<void> setTemperatureUnit(String unit);
}

class AppLocaleService implements LocaleService {
  static const _kTemperatureUnitKey = 'app.temperature_unit';
  String _temperatureUnit = 'C'; // 默认摄氏度
  bool _initialized = false;

  @override
  Future<void> initialize() async {
    final prefs = await SharedPreferences.getInstance();
    final tempUnit = prefs.getString(_kTemperatureUnitKey);
    if (tempUnit == 'F' || tempUnit == 'C') {
      _temperatureUnit = tempUnit!;
    } else {
      // 根据系统区域自动判断
      final sysLocale = WidgetsBinding.instance.platformDispatcher.locale;
      if (sysLocale.countryCode == 'US') {
        _temperatureUnit = 'F';
        await prefs.setString(_kTemperatureUnitKey, 'F');
      } else {
        _temperatureUnit = 'C';
        await prefs.setString(_kTemperatureUnitKey, 'C');
      }
    }
    _initialized = true;
  }

  @override
  String get temperatureUnitText => _temperatureUnit == 'F' ? '°F' : '°C';

  @override
  double convertTemperatureValue(double celsius) {
    if (_temperatureUnit == 'F') {
      return celsius * 9 / 5 + 32;
    }
    return celsius;
  }

  @override
  String get temperatureUnit => _temperatureUnit;

  @override
  Future<void> setTemperatureUnit(String unit) async {
    if (unit != 'C' && unit != 'F') return;
    _temperatureUnit = unit;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kTemperatureUnitKey, unit);
  }

  // 可选：确保已初始化
  bool get isInitialized => _initialized;
}
