import 'package:borneo_app/features/devices/views/devices_screen.dart';
import 'package:borneo_app/features/devices/view_models/grouped_devices_view_model.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import '../../mocks/mocks.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:provider/provider.dart';

// A simple delegate that always returns [FakeGettext] so widgets
// calling `GettextLocalizations.of(context)` don't crash.
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
  testWidgets('AppBar title updates when scene name changes', (WidgetTester tester) async {
    final bus = EventBus();
    final scene = SceneEntity(id: 's1', name: 'Initial', isCurrent: true, lastAccessTime: DateTime.now());
    final sceneMgr = StubSceneManager([scene]);
    final vm = GroupedDevicesViewModel(
      bus,
      sceneMgr,
      StubGroupManager(),
      StubDeviceManager(),
      StubDeviceModuleRegistry(),
      clock: TestClock(),
      gt: FakeGettext(),
    );

    await vm.initialize();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [_FakeGettextDelegate()],
        supportedLocales: const [Locale('en', 'US')],
        home: ChangeNotifierProvider<GroupedDevicesViewModel>.value(value: vm, child: DevicesScreen()),
      ),
    );
    // give the framework a chance to lay out slivers, etc.
    await tester.pumpAndSettle();

    // initial title should reflect the scene name via the translation string
    expect(find.textContaining('Devices in Initial'), findsOneWidget);

    // modify scene name and fire event
    sceneMgr.currentScene = scene.copyWith(name: 'Updated');
    bus.fire(SceneUpdatedEvent(sceneMgr.currentScene));
    await tester.pumpAndSettle();

    expect(find.textContaining('Devices in Updated'), findsOneWidget);
  });
}
