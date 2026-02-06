import 'dart:async';
import 'dart:io';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/device_api.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/widgets.dart';

import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/events.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/shared/view_models/base_view_model.dart';

abstract class BaseDeviceViewModel extends BaseViewModel
    with WidgetsBindingObserver, ViewModelEventBusMixin, ViewModelInitFutureMixin {
  static const Duration timerDuration = Duration(seconds: 1);

  bool _isOnline = false;
  bool _isSuspectedOffline = false;

  final CancellationToken initializationCancelToken = CancellationToken();
  final IDeviceManager deviceManager;
  final String deviceID;
  late DeviceEntity deviceEntity;

  late final StreamSubscription<DeviceBoundEvent> _onDeviceBoundEventSub;
  late final StreamSubscription<DeviceRemovedEvent> _onDeviceRemovedEventSub;
  late final StreamSubscription<DeviceEntityUpdatedEvent> _onDeviceEntityUpdatedEventSub;

  bool isInitialized = false;
  bool _isLoaded = false;

  RssiLevel? get rssiLevel;

  bool get isLoaded => _isLoaded;

  Timer? _timer;

  Timer? get timer => _timer;
  bool get isOnline => _isOnline;
  bool get isSuspectedOffline => _isSuspectedOffline;
  bool _isReconnecting = false;
  Timer? _reconnectTimer;
  DateTime? _reconnectDeadline;
  Duration? _reconnectCountdown;

  bool get isReconnecting => _isReconnecting;
  int? get reconnectCountdownSeconds => _reconnectCountdown?.inSeconds;

  String get name => deviceEntity.name;
  String get model => deviceEntity.model;
  bool get isTimerRunning => _timer?.isActive ?? false;
  BoundDevice? get boundDevice => deviceManager.getBoundDevice(deviceID);

  BaseDeviceViewModel({
    required this.deviceID,
    required this.deviceManager,
    required EventBus globalEventBus,
    super.logger,
  }) {
    super.globalEventBus = globalEventBus;
    WidgetsBinding.instance.addObserver(this);

    _onDeviceBoundEventSub = deviceManager.allDeviceEvents.on<DeviceBoundEvent>().listen((event) {
      if (event.device.id == deviceID) {
        final changed = markOnline(notify: false);
        onDeviceBound();
        if (!isTimerRunning) {
          startTimer();
        }
        if (changed) {
          notifyListeners();
        }
      }
    });

    _onDeviceRemovedEventSub = deviceManager.allDeviceEvents.on<DeviceRemovedEvent>().listen((event) {
      if (event.device.id == deviceID) {
        final changed = markOffline(notify: false);
        onDeviceRemoved();
        if (changed) {
          notifyListeners();
        }
      }
    });

    _onDeviceEntityUpdatedEventSub = deviceManager.allDeviceEvents.on<DeviceEntityUpdatedEvent>().listen((event) {
      if (event.updated.id == deviceID) {
        deviceEntity = event.updated;
        notifyListeners();
      }
    });
  }

  Future<void> initialize() async {
    assert(!isInitialized);
    try {
      deviceEntity = await deviceManager.getDevice(deviceID);
      _isLoaded = true;
      _isOnline = deviceManager.isBound(deviceID);
      _isSuspectedOffline = false;
      await onInitialize();
      if (isOnline) {
        await refreshStatus();
      }
    } on IOException catch (ioex, stackTrace) {
      logger?.e(ioex.toString(), error: ioex, stackTrace: stackTrace);
      if (isOnline) {
        super.notifyAppError('Failed to initialize device: $ioex', stackTrace: stackTrace);
      }
    } catch (e, stackTrace) {
      logger?.e('Failed to initialize device(${deviceEntity.toString()}): $e', error: e, stackTrace: stackTrace);
      super.notifyAppError('Failed to initialize device: $e', stackTrace: stackTrace);
    } finally {
      if (isOnline) {
        startTimer();
      }
      isInitialized = true;
    }
  }

  Future<void> onInitialize();

  @override
  void dispose() {
    assert(!isDisposed);
    if (isTimerRunning) {
      stopTimer();
    }
    _onDeviceBoundEventSub.cancel();
    _onDeviceRemovedEventSub.cancel();
    _onDeviceEntityUpdatedEventSub.cancel();
    _reconnectTimer?.cancel();
    if (!isInitialized) {
      initializationCancelToken.cancel();
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<bool> tryOperateDevice<T extends IDeviceApi>(
    Future<void> Function(T, {CancellationToken? cancelToken}) operation, {
    CancellationToken? cancelToken,
  }) async {
    if (!isOnline || isBusy || !isInitialized) {
      return false;
    }

    final api = boundDevice?.api<T>();
    if (api == null) {
      return false;
    }

    try {
      await operation(api, cancelToken: cancelToken);
    } on CancelledException catch (e, stackTrace) {
      logger?.i('A periodic refresh task has been cancelled.', error: e, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      logger?.i("Failed to operate device: $e", error: e, stackTrace: stackTrace);
    }
    return true;
  }

  void onDeviceBound() {}

  void onDeviceRemoved() {}

  @protected
  void onDeviceSuspectedOffline() {}

  @protected
  void onDeviceConnectionRecovered() {}

  @protected
  bool markOnline({bool notify = true}) {
    final bool wasOffline = !_isOnline;
    final bool wasSuspected = _isSuspectedOffline;
    _isOnline = true;
    _isSuspectedOffline = false;
    _stopReconnectCountdown(notify: false);
    if ((wasOffline || wasSuspected) && !isDisposed) {
      onDeviceConnectionRecovered();
      if (notify) {
        notifyListeners();
      }
      return true;
    }
    return false;
  }

  @protected
  bool markOffline({bool notify = true}) {
    final bool changed = _isOnline || _isSuspectedOffline;
    if (!changed) {
      return false;
    }
    _isOnline = false;
    _isSuspectedOffline = false;
    _stopReconnectCountdown(notify: false);
    if (isTimerRunning) {
      stopTimer();
    }
    if (!isDisposed && notify) {
      notifyListeners();
    }
    return true;
  }

  @protected
  void markSuspectedOffline({bool notify = true}) {
    if (_isSuspectedOffline || isDisposed) {
      return;
    }
    _isSuspectedOffline = true;
    _stopReconnectCountdown(notify: false);
    onDeviceSuspectedOffline();
    if (notify) {
      notifyListeners();
    }
  }

  @protected
  void clearSuspectedOffline({bool notify = true}) {
    if (!_isSuspectedOffline || isDisposed) {
      return;
    }
    _isSuspectedOffline = false;
    onDeviceConnectionRecovered();
    if (notify) {
      notifyListeners();
    }
  }

  @protected
  Future<T> runDeviceCommand<T>(
    Future<T> Function() action, {
    Duration? timeout,
    bool resetSuspectedOnSuccess = true,
  }) async {
    try {
      final future = action();
      final result = timeout != null ? await future.timeout(timeout) : await future;
      if (resetSuspectedOnSuccess && _isSuspectedOffline) {
        clearSuspectedOffline();
      }
      return result;
    } on TimeoutException catch (e, stackTrace) {
      _handleConnectivityFailure(e, stackTrace);
      rethrow;
    } on SocketException catch (e, stackTrace) {
      _handleConnectivityFailure(e, stackTrace);
      rethrow;
    } on IOException catch (e, stackTrace) {
      _handleConnectivityFailure(e, stackTrace);
      rethrow;
    }
  }

  void _handleConnectivityFailure(Object error, StackTrace stackTrace) {
    logger?.w('Device command failed: $error', error: error, stackTrace: stackTrace);
    markSuspectedOffline();
  }

  void _startReconnectCountdown(Duration timeout) {
    _reconnectDeadline = DateTime.now().add(timeout);
    _reconnectCountdown = timeout;
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      _updateReconnectCountdown();
    });
    if (!isDisposed) {
      notifyListeners();
    }
  }

  void _updateReconnectCountdown() {
    if (_reconnectDeadline == null) {
      return;
    }
    final remaining = _reconnectDeadline!.difference(DateTime.now());
    if (remaining.isNegative) {
      _reconnectCountdown = Duration.zero;
      _reconnectTimer?.cancel();
      _reconnectTimer = null;
    } else {
      _reconnectCountdown = Duration(seconds: remaining.inSeconds + 1);
    }
    if (!isDisposed) {
      notifyListeners();
    }
  }

  void _stopReconnectCountdown({bool notify = true}) {
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    _reconnectDeadline = null;
    if (_reconnectCountdown != null) {
      _reconnectCountdown = null;
      if (notify && !isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> reconnect({Duration? timeout}) async {
    if (isDisposed || _isReconnecting) {
      return;
    }

    final Duration effectiveTimeout = timeout ?? const Duration(seconds: 8);
    _isReconnecting = true;
    _startReconnectCountdown(effectiveTimeout);
    if (!isDisposed) {
      notifyListeners();
    }

    try {
      final bound = await deviceManager.tryBind(deviceEntity).timeout(effectiveTimeout, onTimeout: () => false);
      if (!isDisposed) {
        if (bound) {
          markOnline(notify: false);
        }
        if (bound || isOnline || isSuspectedOffline) {
          try {
            await refreshStatus();
          } catch (e, stackTrace) {
            logger?.w('Post-reconnect refresh failed: $e', error: e, stackTrace: stackTrace);
          }
        }
      }
    } on TimeoutException catch (e, stackTrace) {
      logger?.w('Reconnect timed out', error: e, stackTrace: stackTrace);
    } on IOException catch (ioex, stackTrace) {
      logger?.e('Reconnect failed: $ioex', error: ioex, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      logger?.e('Reconnect failed: $e', error: e, stackTrace: stackTrace);
    } finally {
      if (!isDisposed) {
        _isReconnecting = false;
        _stopReconnectCountdown();
        notifyListeners();
      }
    }
  }

  Future<void> refreshStatus({CancellationToken? cancelToken});

  Future<void> _periodicRefreshTask(CancellationToken? cancelToken) async {
    if (!hasListeners || isBusy || !isOnline || isDisposed || (boundDevice?.device.driverData.isBusy ?? true)) {
      return;
    }
    try {
      await refreshStatus(cancelToken: cancelToken);
    } on CancelledException catch (e, stackTrace) {
      logger?.i('A periodic refresh task has been cancelled.', error: e, stackTrace: stackTrace);
    } on IOException catch (ioex, stackTrace) {
      logger?.e('Failed to refresh device status: $ioex', error: ioex, stackTrace: stackTrace);
    } catch (e, stackTrace) {
      logger?.i("Failed to refresh device status: $e", error: e, stackTrace: stackTrace);
      notifyAppError(e.toString(), error: e, stackTrace: stackTrace);
    }
  }

  void startTimer() {
    assert(!isDisposed);

    if (!isTimerRunning) {
      _timer = Timer.periodic(timerDuration, (_) => _periodicRefreshTask(null));
    }
  }

  void stopTimer() {
    assert(!isDisposed);

    if (isTimerRunning) {
      _timer?.cancel();
      _timer = null;
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
      notifyAppError('$e', stackTrace: stackTrace);
    } finally {
      isBusy = false;
      notifyListeners();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      if (isTimerRunning) {
        stopTimer();
      }
    } else if (state == AppLifecycleState.resumed) {
      if (isOnline && !isTimerRunning) {
        startTimer();
      }
    }
  }
}
