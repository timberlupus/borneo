import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/features/devices/view_models/grouped_devices_view_model.dart';
import 'package:borneo_app/core/models/scene_entity.dart';

import 'package:event_bus/event_bus.dart';
import 'package:flutter_test/flutter_test.dart' hide EventDispatcher;
import '../../mocks/mocks.dart';

void main() {
  test('SceneUpdatedEvent causes notification when current scene updated', () async {
    final bus = EventBus();
    final scene = SceneEntity(id: 's1', name: 'First', isCurrent: true, lastAccessTime: DateTime.now());
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

    // mark initialized to avoid reload requirement
    // call initialize which will load empty lists
    await vm.initialize();

    var notified = false;
    vm.addListener(() {
      notified = true;
    });

    // update underlying scene object
    final updated = scene.copyWith(name: 'Changed');
    sceneMgr.currentScene = updated;

    bus.fire(SceneUpdatedEvent(updated));
    // allow microtasks
    await Future<void>.delayed(Duration.zero);

    expect(notified, isTrue);
    expect(vm.currentScene.name, 'Changed');
  });
}
