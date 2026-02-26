import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_colorpicker/flutter_colorpicker.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/channel_settings_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/dimmer_channel_view.dart';
import '../../../mocks/mocks.dart';

class _FakeParent {
  final List<String> names;
  final List<String> colors;

  _FakeParent(int count)
    : names = List<String>.generate(count, (i) => 'ch${i + 1}'),
      colors = List<String>.filled(count, '#FFFFFF');

  String getChannelName(int idx) => names[idx];
  String getChannelColor(int idx) => colors[idx];
  void setChannelName(int idx, String value) {
    names[idx] = value;
  }

  void setChannelColor(int idx, String value) {
    colors[idx] = value;
  }
}

// Localizations delegate used throughout the tests to satisfy
// widgets that call `context.translate()`.
class _FakeGettextDelegate extends LocalizationsDelegate<GettextLocalizations> {
  const _FakeGettextDelegate();

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<GettextLocalizations> load(Locale locale) async => FakeGettext();

  @override
  bool shouldReload(covariant LocalizationsDelegate<GettextLocalizations> old) => false;
}

void main() {
  testWidgets('DimmerChannelView embeds ColorPicker and handles save', (tester) async {
    final parent = _FakeParent(1);
    final vm = ChannelSettingsViewModel(
      index: 0,
      readName: parent.getChannelName,
      readColor: parent.getChannelColor,
      writeName: parent.setChannelName,
      writeColor: parent.setChannelColor,
    );

    // wrap with localization support so translate() works
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_FakeGettextDelegate()],
        supportedLocales: const [Locale('en', 'US')],
        home: DimmerChannelView(vm: vm),
      ),
    );
    // allow asynchronous builds to settle
    await tester.pumpAndSettle();

    // initial state - field should be present and save disabled
    expect(find.byType(TextFormField), findsOneWidget);
    expect(find.byType(ColorPicker), findsOneWidget);
    expect(vm.canSave, isFalse);

    // invalid name disables save
    await tester.enterText(find.byType(TextFormField), '');
    await tester.pumpAndSettle();
    expect(vm.nameValid, isFalse);
    expect(vm.canSave, isFalse);

    // valid name and change color should enable save
    await tester.enterText(find.byType(TextFormField), 'foo');
    await tester.pumpAndSettle();
    expect(vm.nameValid, isTrue);
    expect(vm.canSave, isTrue);

    // tap save; there is no previous route in this test, but the callback
    // should write data back to the parent.
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();

    // parent should have been updated
    expect(parent.names[0], equals('foo'));
  });
}
