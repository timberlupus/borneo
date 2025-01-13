import 'dart:async';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/widgets.dart';

import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:logger/logger.dart';

abstract class BaseDeviceViewModel extends BaseViewModel
    with WidgetsBindingObserver, ViewModelEventBusMixin {
  static const Duration timerDuration = Duration(seconds: 3);

  final Logger? logger;
  final CancellationToken initializationCancelToken = CancellationToken();
  final DeviceManager deviceManager;
  final String deviceID;
  late final DeviceEntity deviceEntity;

  bool isInitialized = false;
  bool _isLoaded = false;

  bool get isLoaded => _isLoaded;

  Timer? _timer;
  bool _isTimerRunning = false;

  Timer? get timer => _timer;
  bool get isOnline => deviceManager.isBound(deviceID);

  String get name => deviceEntity.name;
  String get model => deviceEntity.model;
  bool get isTimerRunning => _isTimerRunning;
  BoundDevice? get boundDevice => deviceManager.getBoundDevice(deviceID);

  BaseDeviceViewModel(
    this.deviceID,
    this.deviceManager, {
    required EventBus globalEventBus,
    this.logger,
  }) {
    super.globalEventBus = globalEventBus;
    WidgetsBinding.instance.addObserver(this);
  }

  Future<void> initialize() async {
    deviceEntity = await deviceManager.getDevice(deviceID);
    _isLoaded = true;
  }

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

  Future<void> periodicRefreshTask();

  void startTimer() {
    assert(!isDisposed);

    if (!_isTimerRunning) {
      _timer = Timer.periodic(
        timerDuration,
        (_) => enqueueJob(
            () => periodicRefreshTask().asCancellable(taskQueueCancelToken)),
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

  void enqueueJob(Future<void> Function() job,
      {int retryTime = 1, bool reportError = true}) {
    super.taskQueue.addJob(retryTime: retryTime, (args) async {
      try {
        await job().asCancellable(taskQueueCancelToken);
      } on CancelledException catch (e, stackTrace) {
        logger?.w('A job has been cancelled.',
            error: e, stackTrace: stackTrace);
      } catch (e, stackTrace) {
        if (reportError) {
          notifyAppError(e.toString(), error: e, stackTrace: stackTrace);
        } else {
          rethrow;
        }
      }
    });
  }

  void enqueueUIJob(Future<void> Function() job,
      {int retryTime = 1, bool notify = true}) {
    super.taskQueue.addJob((args) async {
      if (isBusy) {
        return;
      }
      isBusy = true;
      // notifyListeners();
      try {
        return await job().asCancellable(taskQueueCancelToken);
      } catch (e, stackTrace) {
        logger?.e('$e', error: e, stackTrace: stackTrace);
        notifyAppError('$e');
      } finally {
        if (!super.isDisposed) {
          isBusy = false;
          if (notify) {
            notifyListeners();
          }
        }
      }
    }, retryTime: retryTime);
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
