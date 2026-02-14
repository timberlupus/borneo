import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/events.dart';

class LyfiModeChangedEvent extends DeviceStateChangedEvent {
  final LyfiMode mode;
  const LyfiModeChangedEvent(super.device, {required this.mode});
}

class LyfiStateChangedEvent extends DeviceStateChangedEvent {
  final LyfiState state;
  const LyfiStateChangedEvent(super.device, {required this.state});
}

class LyfiAcclimationChangedEvent extends DeviceStateChangedEvent {
  final AcclimationSettings settings;
  const LyfiAcclimationChangedEvent(super.device, {required this.settings});
}

class LyfiLocationChangedEvent extends DeviceStateChangedEvent {
  final GeoLocation? location;
  const LyfiLocationChangedEvent(super.device, {required this.location});
}

class LyfiCorrectionMethodChangedEvent extends DeviceStateChangedEvent {
  final LedCorrectionMethod method;
  const LyfiCorrectionMethodChangedEvent(super.device, {required this.method});
}

class LyfiMoonConfigChangedEvent extends DeviceStateChangedEvent {
  final MoonConfig config;
  const LyfiMoonConfigChangedEvent(super.device, {required this.config});
}

class LyfiMoonScheduleChangedEvent extends DeviceStateChangedEvent {
  final ScheduleTable schedule;
  const LyfiMoonScheduleChangedEvent(super.device, {required this.schedule});
}

class LyfiMoonCurveChangedEvent extends DeviceStateChangedEvent {
  final List<MoonCurveItem> curve;
  const LyfiMoonCurveChangedEvent(super.device, {required this.curve});
}
