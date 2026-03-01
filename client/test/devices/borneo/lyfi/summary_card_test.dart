import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/devices/borneo/lyfi/manifest.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/summary_device_view_model.dart';
import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import '../../../mocks/mocks.dart';
import 'package:event_bus/event_bus.dart';

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
  testWidgets('Lyfi card center selectors resolve provider and render', (tester) async {
    // build a trivial ViewModel with stub dependencies
    final vm = LyfiSummaryDeviceViewModel(
      DeviceEntity(
        id: 'test',
        address: Uri.parse('http://example.com'),
        fingerprint: 'fp',
        sceneID: 'scene',
        driverID: 'lyfi-driver',
        compatible: '',
        name: 'Test',
        model: 'MODEL',
      ),
      StubDeviceManager(),
      EventBus(),
      gt: FakeGettext(),
    );

    // populate a few fields so selectors have something to read
    vm.ledState = LyfiState.normal;
    vm.ledMode = LyfiMode.manual;
    vm.channelBrightness = [0, 128, 255];
    vm.lyfiDeviceInfo = LyfiDeviceInfo(channelCountMax: 3, channelCount: 3, channels: const []);

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_FakeGettextDelegate()],
        supportedLocales: const [Locale('en', 'US')],
        home: ChangeNotifierProvider<AbstractDeviceSummaryViewModel>.value(
          value: vm,
          child: Builder(
            builder: (context) {
              final meta = LyfiDeviceModuleMetadata();
              // use the public registration API to obtain the same builder
              return meta.summaryContentBuilder!(context, vm);
            },
          ),
        ),
      ),
    );

    // ensure selectors exist and widget tree builds without ProviderNotFoundException
    // ensure no exceptions were raised while building (e.g. ProviderNotFound)
    final exception = tester.takeException();
    expect(exception, isNull);
  });
}
