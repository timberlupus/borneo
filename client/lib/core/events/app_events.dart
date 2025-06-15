import 'package:flutter/material.dart';

class AppErrorEvent {
  final String message;
  final StackTrace? stackTrace;
  final Object? error;
  const AppErrorEvent(this.message, {this.error, this.stackTrace});
}

class ThemeChangedEvent {
  final ThemeMode themeMode;
  ThemeChangedEvent(this.themeMode);
}

final class ThemeModeChangedEvent {
  final ThemeMode mode;
  ThemeModeChangedEvent(this.mode);
}

class AppLocaleChangedEvent {
  final Locale locale;
  AppLocaleChangedEvent(this.locale);
}

class AppTemperatureUnitChangedEvent {
  final String unit; // 'C' or 'F'
  AppTemperatureUnitChangedEvent(this.unit);
}
