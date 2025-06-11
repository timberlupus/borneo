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
