import 'package:borneo_app/features/devices/views/devices_screen.dart';
import 'package:borneo_app/features/devices/view_models/grouped_devices_view_model.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:flutter/material.dart';
import '../../mocks/mocks.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import 'package:provider/provider.dart';

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
        home: ChangeNotifierProvider<GroupedDevicesViewModel>.value(value: vm, child: DevicesScreen()),
      ),
    );

    // initial title should reflect "Initial"
    expect(find.textContaining('Initial'), findsOneWidget);

    // modify scene name and fire event
    sceneMgr.currentScene = scene.copyWith(name: 'Updated');
    bus.fire(SceneUpdatedEvent(sceneMgr.currentScene));
    await tester.pump();

    expect(find.textContaining('Updated'), findsOneWidget);
  });
}
