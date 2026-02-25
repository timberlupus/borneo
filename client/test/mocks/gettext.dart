import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';

/// Always returns the key verbatim; avoids needing real localization in tests.
class FakeGettext implements GettextLocalizations {
  @override
  String translate(
    String key, {
    String? domain,
    String? keyPlural,
    String msgctxt = '',
    Map<String, Object>? nArgs,
    List<Object>? pArgs,
  }) {
    if (nArgs != null && nArgs.isNotEmpty) {
      nArgs.forEach((name, value) {
        key = key.replaceAll('{$name}', value.toString());
      });
    }
    if (pArgs != null && pArgs.isNotEmpty) {
      for (var i = 0; i < pArgs.length; i++) {
        key = key.replaceAll('{$i}', pArgs[i].toString());
      }
    }
    return key;
  }
}
