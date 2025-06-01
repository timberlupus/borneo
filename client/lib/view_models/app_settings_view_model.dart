import 'package:borneo_app/view_models/abstract_screen_view_model.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

import '../events.dart';

const kBrightnessKey = "app.brightness";

class AppSettingsViewModel extends AbstractScreenViewModel {
  final EventBus globalEventBus;
  final Logger? logger;

  AppSettingsViewModel({required this.globalEventBus, this.logger});

  ThemeMode _themeMode = ThemeMode.system;
  ThemeMode get themeMode => _themeMode;

  static const _kBrightnessKey = kBrightnessKey;

  @override
  Future<void> onInitialize() async {
    final prefs = await SharedPreferences.getInstance();
    final idx = prefs.getInt(_kBrightnessKey);
    if (idx != null && idx >= 0 && idx < ThemeMode.values.length) {
      _themeMode = ThemeMode.values[idx];
    } else {
      _themeMode = ThemeMode.system;
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
}
