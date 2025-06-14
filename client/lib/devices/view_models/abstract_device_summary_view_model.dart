import 'dart:async';
import 'dart:io';

import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_app/core/services/device_manager.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';

import '../../shared/view_models/base_view_model.dart';

abstract class AbstractDeviceSummaryViewModel extends BaseViewModel
    with ViewModelEventBusMixin, ViewModelInitFutureMixin {
  final DeviceManager deviceManager;
  final DeviceEntity deviceEntity;
  var isInitialized = false;

  bool _isOnline;
  bool get isOnline => _isOnline;

  String get name => deviceEntity.name;

  EventBus get deviceEvents => deviceManager.deviceEvents;

  late final StreamSubscription<DeviceBoundEvent> _boundEventSub;
  late final StreamSubscription<DeviceRemovedEvent> _removedEventSub;
  late bool _isPowerOn = false;
  bool get isPowerOn => _isPowerOn;
  late final StreamSubscription<DevicePowerOnOffChangedEvent> _powerEventSub;

  AbstractDeviceSummaryViewModel(this.deviceEntity, this.deviceManager, EventBus globalEventBus)
    : _isOnline = deviceManager.isBound(deviceEntity.id) {
    super.globalEventBus = globalEventBus;
    _boundEventSub = deviceManager.deviceEvents.on<DeviceBoundEvent>().listen(_onBound);
    _removedEventSub = deviceManager.deviceEvents.on<DeviceRemovedEvent>().listen(_onRemoved);
    _powerEventSub = deviceManager.deviceEvents.on<DevicePowerOnOffChangedEvent>().listen(_onPowerChanged);
  }

  Future<void> initialize({CancellationToken? cancelToken}) async {
    try {
      if (deviceManager.isBound(deviceEntity.id)) {
        final bound = deviceManager.getBoundDevice(deviceEntity.id);
        final wotDevice = bound.wotAdapter.device;
        if (wotDevice.hasCapability("OnOffSwitch")) {
          final onProp = wotDevice.properties["on"]!;
          _isPowerOn = onProp.value as bool;
        }
      }
      await onInitialize(cancelToken: cancelToken);
    } on IOException catch (ioex, stackTrace) {
      logger?.e(ioex.toString(), error: ioex, stackTrace: stackTrace);
      if (isOnline) {
        super.notifyAppError('Failed to initialize device: $ioex', stackTrace: stackTrace);
      }
    } catch (e, stackTrace) {
      logger?.e('Failed to initialize device(${deviceEntity.toString()}): $e', error: e, stackTrace: stackTrace);
      super.notifyAppError('Failed to initialize device: $e', error: e, stackTrace: stackTrace);
    } finally {
      isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> onInitialize({CancellationToken? cancelToken});

  @override
  void dispose() {
    _boundEventSub.cancel();
    _removedEventSub.cancel();
    _powerEventSub.cancel();
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
      notifyListeners();
    }
  }

  void _onPowerChanged(DevicePowerOnOffChangedEvent event) {
    if (event.device.id == deviceEntity.id) {
      _isPowerOn = event.onOff;
      notifyListeners();
    }
  }
}
