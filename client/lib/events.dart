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

class AppLocaleChangedEvent {
  final Locale locale;
  AppLocaleChangedEvent(this.locale);
}
