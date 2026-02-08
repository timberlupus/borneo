import 'dart:async';

import 'package:borneo_app/devices/borneo/lyfi/core/wot.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/events.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/widgets.dart';
import 'package:lw_wot/wot.dart';

import '../../shared/view_models/base_view_model.dart';

abstract class AbstractDeviceSummaryViewModel extends BaseViewModel with ViewModelEventBusMixin {
  final IDeviceManager deviceManager;
  DeviceEntity deviceEntity;
  var isInitialized = false;

  WotThing? wotThing;

  bool _isOnline;
  bool get isOnline => _isOnline;

  String get name => deviceEntity.name;

  EventBus get deviceEvents => deviceManager.allDeviceEvents;

  late final StreamSubscription<DeviceBoundEvent> _boundEventSub;
  late final StreamSubscription<DeviceRemovedEvent> _removedEventSub;
  late final StreamSubscription<DeviceEntityUpdatedEvent> _deviceUpdatedSub;
  late final StreamSubscription<LoadingDriverFailedEvent> _loadingFailedEventSub;
  late final StreamSubscription<CurrentSceneDevicesReloadedEvent> _sceneReloadedSub;

  late bool _isPowerOn = false;
  bool get isPowerOn => _isPowerOn;

  AbstractDeviceSummaryViewModel(
    this.deviceEntity,
    this.deviceManager,
    EventBus globalEventBus, {
    required super.gt,
    super.logger,
  }) : _isOnline = deviceManager.isBound(deviceEntity.id) {
    super.globalEventBus = globalEventBus;
    _boundEventSub = deviceManager.allDeviceEvents.on<DeviceBoundEvent>().listen(_onBound);
    _removedEventSub = deviceManager.allDeviceEvents.on<DeviceRemovedEvent>().listen(_onRemoved);
    _deviceUpdatedSub = deviceManager.allDeviceEvents.on<DeviceEntityUpdatedEvent>().listen(_onDeviceUpdated);
    _loadingFailedEventSub = deviceManager.allDeviceEvents.on<LoadingDriverFailedEvent>().listen(_onLoadingFailed);
    _sceneReloadedSub = globalEventBus.on<CurrentSceneDevicesReloadedEvent>().listen(_onSceneReloaded);
    wotThing?.addSubscriber(_onPowerPropertyChanged);

    _refreshWotThing();
  }

  @override
  void dispose() {
    _boundEventSub.cancel();
    _removedEventSub.cancel();
    _deviceUpdatedSub.cancel();
    _loadingFailedEventSub.cancel();
    _sceneReloadedSub.cancel();
    wotThing?.removeSubscriber(_onPowerPropertyChanged);
    super.dispose();
  }

  Future<bool> tryConnect() async {
    return await deviceManager.tryBind(deviceEntity);
  }

  void _onBound(DeviceBoundEvent event) {
    if (event.device.id == deviceEntity.id) {
      _isOnline = true;
      notifyListeners();
    }
  }

  void _onRemoved(DeviceRemovedEvent event) {
    if (event.device.id == deviceEntity.id) {
      _isOnline = false;
      _refreshWotThing();
      notifyListeners();
    }
  }

  void _onPowerPropertyChanged(WotMessage msg) {
    final onValue = wotThing?.getProperty(LyfiKnownProperties.kOn);
    if (onValue != null && _isPowerOn != onValue) {
      _isPowerOn = onValue as bool;
      notifyListeners();
    }
  }

  @protected
  void onWotThingChanged(WotThing? oldThing, WotThing? newThing) {
    oldThing?.removeSubscriber(_onPowerPropertyChanged);
    newThing?.addSubscriber(_onPowerPropertyChanged);
  }

  void _refreshWotThing() {
    final oldThing = wotThing;
    wotThing = deviceManager.getWotThing(deviceEntity.id);
    if (wotThing != null && wotThing!.hasProperty(LyfiKnownProperties.kOn)) {
      final onProp = wotThing?.getProperty(LyfiKnownProperties.kOn);
      if (onProp != null) {
        _isPowerOn = onProp as bool;
      }
    }

    if (oldThing != wotThing) {
      onWotThingChanged(oldThing, wotThing);
    }
  }

  void _onDeviceUpdated(DeviceEntityUpdatedEvent event) {
    if (event.updated.id == deviceEntity.id) {
      deviceEntity = event.updated;
      notifyListeners();
    }
  }

  void _onLoadingFailed(LoadingDriverFailedEvent event) {
    if (event.device.id == deviceEntity.id) {
      deviceEntity.lastErrorMessage = event.message ?? event.error?.toString() ?? 'Unknown error';
      notifyListeners();
    }
  }

  void _onSceneReloaded(CurrentSceneDevicesReloadedEvent event) {
    if (event.scene.id == deviceEntity.sceneID) {
      _refreshWotThing();
      notifyListeners();
    }
  }
}
