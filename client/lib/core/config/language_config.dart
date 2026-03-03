import 'package:flutter/material.dart';

/// Language configuration
/// Unified management of supported languages and conversion logic
class LanguageConfig {
  /// Language definition: code -> display name
  /// Only store necessary information, don't create Locale objects
  static const Map<String, String> _languages = {
    'en_US': 'English (US)',
    'es': 'Español',
    'de': 'Deutsch',
    'zh_CN': '中文 (简体)',
  };

  /// Get all supported locales
  static List<Locale> get supportedLocales => _languages.keys.map(_parseLocale).toList();

  /// Get all supported language codes (for storage)
  static List<String> get supportedLanguageCodes => _languages.keys.toList();

  /// Parse language code string to Locale
  static Locale _parseLocale(String code) {
    final parts = code.split('_');
    return Locale(parts[0], parts.length > 1 ? parts[1] : null);
  }

  /// Get storage language code from Locale
  static String localeToLanguageCode(Locale locale) {
    // Complete match (including countryCode)
    if (locale.countryCode != null) {
      final fullCode = '${locale.languageCode}_${locale.countryCode}';
      if (_languages.containsKey(fullCode)) {
        return fullCode;
      }
    }

    // Match only languageCode
    final matching = _languages.entries.where((entry) => entry.key.split('_')[0] == locale.languageCode).firstOrNull;

    return matching?.key ?? 'en_US'; // Default to English
  }

  /// Get Locale from language code
  static Locale languageCodeToLocale(String? languageCode) {
    if (languageCode == null || !_languages.containsKey(languageCode)) {
      return const Locale('en', 'US');
    }
    return _parseLocale(languageCode);
  }

  /// Get the display name of language
  static String getLanguageName(String languageCode) {
    return _languages[languageCode] ?? languageCode;
  }

  /// Get the display name of Locale
  static String getLocaleDisplayName(Locale locale) {
    final code = localeToLanguageCode(locale);
    return getLanguageName(code);
  }

  /// Get language code from system Locale
  /// If system language is in support list, use it; otherwise default to English
  static String getDefaultLanguageCode(Locale systemLocale) {
    // First try complete match (language code + country code)
    if (systemLocale.countryCode != null) {
      final fullCode = '${systemLocale.languageCode}_${systemLocale.countryCode}';
      if (_languages.containsKey(fullCode)) {
        return fullCode;
      }
    }

    // Then try to match only language code
    final matching = _languages.entries
        .where((entry) => entry.key.split('_')[0] == systemLocale.languageCode)
        .firstOrNull;

    return matching?.key ?? 'en_US'; // Default to English if no match
  }
}
