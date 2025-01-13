import 'package:borneo_app/view_models/abstract_screen_view_model.dart';
import 'package:flutter/material.dart';

import 'package:shared_preferences/shared_preferences.dart';

const kBrightnessKey = "app.brightness";

class AppSettingsViewModel extends AbstractScreenViewModel {
  AppSettingsViewModel();

  late ThemeMode themeMode;

  @override
  Future<void> onInitialize() async {
    final perfs = SharedPreferencesAsync();
    themeMode = ThemeMode.values[await perfs.getInt(kBrightnessKey) ?? 0];
  }

  Future<void> changeBrightness(ThemeMode mode) async {
    themeMode = mode;
    notifyListeners();
  }
}
