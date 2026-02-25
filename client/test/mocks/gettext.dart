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
  }) => key;
}
