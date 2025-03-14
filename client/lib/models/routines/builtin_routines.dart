import 'package:borneo_kernel_abstractions/device_capability.dart';
import 'package:borneo_app/models/routines/abstract_routine.dart';
import 'package:borneo_app/services/device_manager.dart';

final class PowerOffAllRoutine extends AbstractBuiltinRoutine {
  PowerOffAllRoutine()
    : super(
        name: 'Power off all',
        iconAssetPath: 'assets/images/routines/icons/power-off.svg',
      );

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any(
      (d) => d.api() is IPowerOnOffCapability,
    );
  }

  @override
  Future<void> execute(DeviceManager deviceManager) async {
    for (final bound in deviceManager.boundDevices) {
      final api = bound.api<IPowerOnOffCapability>();
      api.setOnOff(bound.device, false);
    }
  }
}

final class FeedModeRoutine extends AbstractBuiltinRoutine {
  FeedModeRoutine()
    : super(
        name: 'Feed mode',
        iconAssetPath: 'assets/images/routines/icons/feed.svg',
      );

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    // Feed mode operations:
    // * Power off all pumps
    return deviceManager.boundDevices.any(
      (d) => d.api() is IPowerOnOffCapability,
    );
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
    : super(
        name: 'Water change mode',
        iconAssetPath: 'assets/images/routines/icons/water-change.svg',
      );

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any(
      (d) => d.api() is IPowerOnOffCapability,
    );
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
  DryScapeModeRoutine()
    : super(
        name: 'Dry scape mode',
        iconAssetPath: 'assets/images/routines/icons/dry-scape.svg',
      );

  @override
  bool checkAvailable(DeviceManager deviceManager) {
    return deviceManager.boundDevices.any(
      (d) => d.api() is IPowerOnOffCapability,
    );
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
