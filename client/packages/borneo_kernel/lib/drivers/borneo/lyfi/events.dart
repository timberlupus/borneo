import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/events.dart';

class LyfiModeChangedEvent extends KnownDeviceEvent {
  final LedRunningMode mode;
  const LyfiModeChangedEvent(super.device, this.mode);
}

class LyfiStateChangedEvent extends KnownDeviceEvent {
  final LedState state;
  const LyfiStateChangedEvent(super.device, this.state);
}
