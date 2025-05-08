import 'dart:async';
import 'dart:io';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/widgets.dart';

import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/view_models/base_view_model.dart';

abstract class BaseDeviceViewModel extends BaseViewModel with WidgetsBindingObserver, ViewModelEventBusMixin {
  static const Duration timerDuration = Duration(seconds: 1);

  final CancellationToken initializationCancelToken = CancellationToken();
  final DeviceManager deviceManager;
  final String deviceID;
  late final DeviceEntity deviceEntity;

  bool isInitialized = false;
  bool _isLoaded = false;

  RssiLevel? get rssiLevel;

  bool get isLoaded => _isLoaded;

  Timer? _timer;
  bool _isTimerRunning = false;

  Timer? get timer => _timer;
  bool get isOnline => deviceManager.isBound(deviceID);

  String get name => deviceEntity.name;
  String get model => deviceEntity.model;
  bool get isTimerRunning => _isTimerRunning;
  BoundDevice? get boundDevice => deviceManager.getBoundDevice(deviceID);

  BaseDeviceViewModel({
    required this.deviceID,
    required this.deviceManager,
    required EventBus globalEventBus,
    super.logger,
  }) {
    super.globalEventBus = globalEventBus;
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> initialize() async {
    try {
      deviceEntity = await deviceManager.getDevice(deviceID);
      _isLoaded = true;
      await onInitialize();
      if (isOnline) {
        await refreshStatus();
      }
    } on IOException catch (ioex, stackTrace) {
      logger?.e(ioex.toString(), error: ioex, stackTrace: stackTrace);
      if (isOnline) {
        super.notifyAppError('Failed to initialize device: $ioex');
      }
    } catch (e, stackTrace) {
      logger?.e('Failed to initialize device(${deviceEntity.toString()}): $e', error: e, stackTrace: stackTrace);
      super.notifyAppError('Failed to initialize device: $e');
    } finally {
      startTimer();
      isInitialized = true;
    }
  }

  Future<void> onInitialize();

  @override
  void dispose() {
    assert(!isDisposed);
    stopTimer();
    if (!isInitialized) {
      initializationCancelToken.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> refreshStatus();

  Future<void> _periodicRefreshTask() async {
    if (!hasListeners || isBusy || !isOnline) {
      return;
    }
    try {
      await refreshStatus().asCancellable(taskQueueCancelToken);
    } on CancelledException catch (e, stackTrace) {
      logger?.i('A periodic refresh task has been cancelled.', error: e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      notifyAppError(e.toString(), error: e, stackTrace: stackTrace);
    } finally {
      notifyListeners();
    }
  }

  void startTimer() {
    assert(!isDisposed);

    if (!_isTimerRunning) {
      _timer = Timer.periodic(
        timerDuration,
        (_) => enqueueJob(() => _periodicRefreshTask().asCancellable(taskQueueCancelToken)),
      );
      _isTimerRunning = true;
    }
  }

  void stopTimer() {
    assert(!isDisposed);

    if (_isTimerRunning) {
      _timer?.cancel();
      _timer = null;
      _isTimerRunning = false;
    }
  }

  Future<void> delete() async {
    assert(!isBusy);
    stopTimer();
    isBusy = true;
    try {
      await deviceManager.delete(deviceID);
    } catch (e, stackTrace) {
      logger?.e('$e', error: e, stackTrace: stackTrace);
      notifyAppError('$e');
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      stopTimer();
    } else if (state == AppLifecycleState.resumed) {
      startTimer();
    }
  }
}
