import 'dart:async';

import 'package:borneo_app/events.dart';
import 'package:borneo_app/services/blob_manager.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/services/group_manager.dart';
import 'package:borneo_app/services/scene_manager.dart';
import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

enum TabIndices { scenes, devices, my }

class MainViewModel extends BaseViewModel with ViewModelEventBusMixin {
  static final Duration kStartupScanningDuration = Duration(seconds: 5);
  final IBlobManager _blobManager;
  final SceneManager _sceneManager;
  final GroupManager _groupManager;
  final DeviceManager _deviceManager;
  final Logger? logger;
  TabIndices _currentIndex = TabIndices.scenes;
  bool _isInitialized = false;

  late final StreamSubscription<AppErrorEvent> _appErrorEventSub;
  late final StreamSubscription<DeviceDiscoveringStartedEvent>
  _deviceDiscoveringStartedEventSub;
  late final StreamSubscription<DeviceDiscoveringStoppedEvent>
  _deviceDiscoveringStoppedEventSub;

  final List<AppErrorEvent> _errorsStack = [];

  String get errorMessage => _errorsStack.last.message;

  bool get hasError => _errorsStack.isNotEmpty;

  TabIndices get currentTabIndex => _currentIndex;

  bool get isInitialized => _isInitialized;

  String get currentSceneName =>
      _isInitialized && _sceneManager.isInitialized
          ? _sceneManager.current.name
          : 'N/A';

  bool get isScanningDevices => _deviceManager.isDiscoverying;

  MainViewModel(
    EventBus globalEventBus,
    this._blobManager,
    this._sceneManager,
    this._groupManager,
    this._deviceManager, {
    this.logger,
  }) {
    this.globalEventBus = globalEventBus;
    _appErrorEventSub = globalEventBus.on<AppErrorEvent>().listen(_onAppError);
    _deviceDiscoveringStartedEventSub = _deviceManager.deviceEvents
        .on<DeviceDiscoveringStartedEvent>()
        .listen(_onDeviceDiscoveringStarted);
    _deviceDiscoveringStoppedEventSub = _deviceManager.deviceEvents
        .on<DeviceDiscoveringStoppedEvent>()
        .listen(_onDeviceDiscoveringStopped);
  }

  Future<void> initialize() async {
    if (isInitialized) {
      return;
    }
    logger?.i('Starting to initialize MainViewModel...');
    try {
      await _blobManager.initialize();
      await _sceneManager.initialize(_groupManager, _deviceManager);
      await _groupManager.initialize();
      await _deviceManager.initialize();
      logger?.i('MainViewModel initialized.');
      await _deviceManager.kernel.startDevicesScanning(
        timeout: kStartupScanningDuration,
      );
    } finally {
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    if (!isDisposed) {
      _appErrorEventSub.cancel();
      _errorsStack.clear();
      _deviceDiscoveringStartedEventSub.cancel();
      _deviceDiscoveringStoppedEventSub.cancel();
    }
    super.dispose();
  }

  void setIndex(TabIndices index) {
    _currentIndex = index;
    notifyListeners();
  }

  void clearError() {
    if (_errorsStack.isNotEmpty) {
      _errorsStack.removeLast();
      notifyListeners();
    }
  }

  void _onAppError(AppErrorEvent event) {
    if (_errorsStack.isEmpty ||
        _errorsStack.last.error.runtimeType != event.error.runtimeType) {
      _errorsStack.add(event);
      notifyListeners();
    }
    logger?.e(
      'APP_ERROR: ${event.message}',
      error: event.error,
      stackTrace: event.stackTrace,
    );
  }

  void _onDeviceDiscoveringStarted(DeviceDiscoveringStartedEvent event) {
    if (!isDisposed && !isBusy) {
      notifyListeners();
    }
  }

  void _onDeviceDiscoveringStopped(DeviceDiscoveringStoppedEvent event) {
    if (!isDisposed && !isBusy) {
      notifyListeners();
    }
  }
}
