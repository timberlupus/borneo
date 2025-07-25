import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/events.dart';

class LyfiModeChangedEvent extends KnownDeviceEvent {
  final LyfiMode mode;
  const LyfiModeChangedEvent(super.device, this.mode);
}

class LyfiStateChangedEvent extends KnownDeviceEvent {
  final LyfiState state;
  const LyfiStateChangedEvent(super.device, this.state);
}

class LyfiScheduleChangedEvent extends KnownDeviceEvent {
  final List<ScheduledInstant> schedule;
  const LyfiScheduleChangedEvent(super.device, this.schedule);
}

class LyfiAcclimationChangedEvent extends KnownDeviceEvent {
  final AcclimationSettings settings;
  const LyfiAcclimationChangedEvent(super.device, this.settings);
}

class LyfiLocationChangedEvent extends KnownDeviceEvent {
  final GeoLocation? location;
  const LyfiLocationChangedEvent(super.device, this.location);
}

class LyfiCorrectionMethodChangedEvent extends KnownDeviceEvent {
  final LedCorrectionMethod method;
  const LyfiCorrectionMethodChangedEvent(super.device, this.method);
}
