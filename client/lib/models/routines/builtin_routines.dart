import 'package:borneo_kernel_abstractions/device_capability.dart';
import 'package:borneo_app/models/routines/abstract_routine.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/routine_history_store.dart';
import 'package:collection/collection.dart';

final class PowerOffAllRoutine extends AbstractBuiltinRoutine with PersistentRoutineMixin {
  PowerOffAllRoutine() : super(name: 'Power off all', iconAssetPath: 'assets/images/routines/icons/power-off.svg');

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability);
  }

  /// Execute routine
  @override
  Future<void> execute(DeviceManager deviceManager) async {
    // For backward compatibility, call executeAndPersist
    await executeAndPersist(deviceManager, null, id);
  }

  @override
  Future<void> executeAndPersist(DeviceManager deviceManager, RoutineHistoryStore? store, String routineId) async {
    final steps = <Map<String, dynamic>>[];
    for (final bound in deviceManager.boundDevices) {
      final api = bound.api<IPowerOnOffCapability>();
      final prevState = await api.getOnOff(bound.device);
      await api.setOnOff(bound.device, false);
      steps.add({'deviceId': bound.device.id, 'prevState': prevState});
    }
    if (store != null) {
      await store.addRecord(RoutineHistoryRecord(routineId: routineId, timestamp: DateTime.now(), steps: steps));
    }
  }

  /// Undo routine
  @override
  Future<void> undo(DeviceManager deviceManager) async {
    // For backward compatibility, call undoFromHistory
    await undoFromHistory(deviceManager, null, id);
  }

  @override
  Future<void> undoFromHistory(DeviceManager deviceManager, RoutineHistoryStore? store, String routineId) async {
    if (store == null) return;
    final records = await store.getAllRecords();
    final last = records.where((r) => r.routineId == routineId).lastOrNull;
    if (last == null) return;
    for (final step in last.steps.reversed) {
      final deviceId = step['deviceId'];
      final prevState = step['prevState'];
      final bound = deviceManager.boundDevices.where((d) => d.device.id == deviceId).lastOrNull;
      if (bound == null) continue;
      final api = bound.api<IPowerOnOffCapability>();
      await api.setOnOff(bound.device, prevState);
    }
    // Optional: clear history
    // await store.clear();
  }
}

final class FeedModeRoutine extends AbstractBuiltinRoutine {
  FeedModeRoutine() : super(name: 'Feed mode', iconAssetPath: 'assets/images/routines/icons/feed.svg');

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    // Feed mode operations:
    // * Power off all pumps
    return deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability);
  }

  @override
  Future<void> execute(DeviceManager deviceManager) async {
    for (final bound in deviceManager.boundDevices) {
      final api = bound.api<IPowerOnOffCapability>();
      api.setOnOff(bound.device, false);
    }
  }
}

final class WaterChangeModeRoutine extends AbstractBuiltinRoutine {
  WaterChangeModeRoutine()
    : super(name: 'Water change mode', iconAssetPath: 'assets/images/routines/icons/water-change.svg');

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability);
  }

  @override
  Future<void> execute(DeviceManager deviceManager) async {
    // Water change mode operations:
    // * Set the lights to around 20% to avoid burning plants/corals.
    // * Stop or power off all dosers, pumps, heaters, and coolers.
    for (final bound in deviceManager.boundDevices) {
      final api = bound.api<IPowerOnOffCapability>();
      api.setOnOff(bound.device, false);
    }
  }
}

final class DryScapeModeRoutine extends AbstractBuiltinRoutine {
  DryScapeModeRoutine() : super(name: 'Dry scape mode', iconAssetPath: 'assets/images/routines/icons/dry-scape.svg');

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any((d) => d.api() is IPowerOnOffCapability);
  }

  @override
  Future<void> execute(DeviceManager deviceManager) async {
    // Dry scape mode operations:
    // * Set the lights to around 20% to avoid burning plants/corals.
    // * Power off everything else.
    for (final bound in deviceManager.boundDevices) {
      final api = bound.api<IPowerOnOffCapability>();
      api.setOnOff(bound.device, false);
    }
  }
}
