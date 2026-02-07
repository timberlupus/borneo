import 'dart:async';

import 'package:lw_wot/event.dart';
import 'package:lw_wot/property.dart';

import 'package:borneo_kernel_abstractions/events.dart';

/// Generic WotProperty that handles event subscription and value mapping
class ObservableWotProperty<T, E> extends WotProperty<T> {
  final DeviceEventBus deviceEvents;
  final String eventName;
  final T Function(E event) mapper;
  final bool subscribe;
  StreamSubscription? _eventSubscription;

  ObservableWotProperty({
    required super.thing,
    required this.deviceEvents,
    required super.name,
    required super.value,
    required super.metadata,
    required this.eventName,
    required this.mapper,
    this.subscribe = true,
  }) {
    if (subscribe) {
      subscribeToEvents();
    }
  }

  void subscribeToEvents() {
    _eventSubscription = deviceEvents.on<E>().listen((event) {
      final newValue = mapper(event);
      value.notifyOfExternalUpdate(newValue);
      thing.addEvent(WotEvent(thing: thing, name: eventName, data: newValue));
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
