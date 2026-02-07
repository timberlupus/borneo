// dart format width=120

import 'dart:async';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:lw_wot/wot.dart';

/// Custom WotProperty for state that handles its own event subscription
class LyfiStateProperty extends WotProperty<String> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiStateProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiStateChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.state.name);
      thing.addEvent(WotEvent(thing: thing, name: 'stateChanged', data: event.state.name));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for mode that handles its own event subscription
class LyfiModeProperty extends WotProperty<String> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiModeProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiModeChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.mode.name);
      thing.addEvent(WotEvent(thing: thing, name: 'modeChanged', data: event.mode.name));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for power on/off that handles its own event subscription
class LyfiPowerProperty extends WotProperty<bool> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiPowerProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<DevicePowerOnOffChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.onOff);
      thing.addEvent(WotEvent(thing: thing, name: 'powerChanged', data: event.onOff));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for schedule that handles its own event subscription
class LyfiScheduleProperty extends WotProperty<ScheduleTable> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiScheduleProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiScheduleChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.schedule);
      thing.addEvent(WotEvent(thing: thing, name: 'scheduleChanged', data: event.schedule));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for acclimation settings that handles its own event subscription
class LyfiAcclimationProperty extends WotProperty<AcclimationSettings> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiAcclimationProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiAcclimationChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.settings);
      thing.addEvent(WotEvent(thing: thing, name: 'acclimationChanged', data: event.settings));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for location that handles its own event subscription
class LyfiLocationProperty extends WotProperty<GeoLocation?> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiLocationProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiLocationChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.location);
      thing.addEvent(WotEvent(thing: thing, name: 'locationChanged', data: event.location));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}

/// Custom WotProperty for correction method that handles its own event subscription
class LyfiCorrectionMethodProperty extends WotProperty<String> {
  StreamSubscription? _eventSubscription;
  final DeviceEventBus deviceEvents;

  LyfiCorrectionMethodProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
  });

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<LyfiCorrectionMethodChangedEvent>().listen((event) {
      value.notifyOfExternalUpdate(event.method.name);
      thing.addEvent(WotEvent(thing: thing, name: 'correctionMethodChanged', data: event.method.name));
    });
  }

  void unsubscribeFromEvents() {
    _eventSubscription?.cancel();
    _eventSubscription = null;
  }

  @override
  void dispose() {
    unsubscribeFromEvents();
    super.dispose();
  }
}
