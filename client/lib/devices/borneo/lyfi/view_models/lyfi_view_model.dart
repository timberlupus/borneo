import 'dart:async';
import 'dart:io';
import 'package:borneo_app/core/services/local_service.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/settings_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/sun_editor_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:intl/intl.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/manual_editor_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/schedule_editor_view_model.dart';

import 'editor/ieditor.dart';

enum EditorStatus { idle, loading, ready, error }

@immutable
class EditorState {
  final LyfiMode mode;
  final EditorStatus status;
  final IEditor? editor;
  final Object? error;

  const EditorState({required this.mode, required this.status, required this.editor, this.error});

  EditorState copyWith({
    LyfiMode? mode,
    EditorStatus? status,
    IEditor? editor,
    Object? error,
    bool clearError = false,
  }) {
    return EditorState(
      mode: mode ?? this.mode,
      status: status ?? this.status,
      editor: editor ?? this.editor,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class LyfiViewModel extends BaseLyfiDeviceViewModel {
  static const initializationTimeout = Duration(seconds: 5);
  static const Duration _commandTimeout = Duration(seconds: 3);
  static const Duration _rapidProbeTimeout = Duration(seconds: 1);
  static const Duration _rapidProbeInterval = Duration(milliseconds: 600);
  static const int _rapidProbeAttempts = 3;
  static const int tempMax = 105;
  static final int tempSetpoint = 45;

  static final DateFormat deviceDateFormat = DateFormat('yyyy-MM-dd HH:mm');

  bool _isDisposed = false;

  final ILocaleService localeService;
  Future<void>? _rapidProbeTask;

  Duration _temporaryDuration = Duration.zero;
  Duration get temporaryDuration => _temporaryDuration;

  Duration _temporaryRemaining = Duration.zero;
  Duration get temporaryRemaining => _temporaryRemaining;

  Duration get commandTimeout => _commandTimeout;

  bool get canLockOrUnlock => !isBusy && !isSuspectedOffline && isOn;
  bool get canUnlock =>
      !isBusy &&
      super.isOnline &&
      !isSuspectedOffline &&
      isOn &&
      isLocked &&
      (super.state == LyfiState.normal || super.state == LyfiState.temporary);

  bool get canChangeSettings =>
      !isBusy &&
      super.isOnline &&
      !isSuspectedOffline &&
      isLocked &&
      (super.state == LyfiState.normal || super.state == LyfiState.temporary);

  bool get canTimedOn => !isBusy && !isSuspectedOffline && (!isOn || super.mode == LyfiMode.scheduled);

  EditorState _editorState = const EditorState(mode: LyfiMode.manual, status: EditorStatus.idle, editor: null);
  EditorState get editorState => _editorState;
  final ScheduleTable scheduledInstants = [];
  final ScheduleTable sunInstants = [];

  int? get currentTempRaw => _currentTemperature;
  int? get currentTemp => _currentTemperature == null
      ? null
      : localeService.convertTemperatureValue(_currentTemperature!.toDouble()).toInt();

  String get temperatureUnitText => localeService.temperatureUnitText;

  // LyFi device status and info
  double? _fanPowerRatio = 0.0;
  double? get fanPowerRatio => _fanPowerRatio;

  FanMode? _fanMode;
  FanMode? get fanMode => _fanMode;

  StreamSubscription<String>? _fanModeSubscription;

  StreamSubscription<int>? _fanPowerSubscription;

  int? _currentTemperature;
  StreamSubscription<int?>? _temperatureSubscription;

  StreamSubscription<double?>? _voltageSubscription;
  StreamSubscription<double?>? _currentSubscription;
  StreamSubscription<double?>? _powerSubscription;
  StreamSubscription<Duration>? _temporaryDurationSubscription;
  StreamSubscription<Duration>? _temporaryRemainingSubscription;

  StreamSubscription<String>? _stateSubscription;
  StreamSubscription<String>? _modeSubscription;
  StreamSubscription<ScheduleTable>? _sunScheduleSubscription;

  double _overallBrightness = 0;
  double get overallBrightness => _overallBrightness;

  final List<ValueNotifier<int>> _channels = [];
  List<ValueNotifier<int>> get channels => _channels;

  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < _channels.length) {
      _channels[index].value = value;
    }
  }

  LyfiViewModel({
    required super.deviceManager,
    required super.globalEventBus,
    required super.notification,
    required super.wotThing,
    required this.localeService,
    required super.gt,
    super.logger,
  });

  Future<T> executeLyfiCommand<T>(
    Future<T> Function() action, {
    Duration? timeout,
    bool resetSuspectedOnSuccess = true,
  }) {
    return runDeviceCommand(
      action,
      timeout: timeout ?? _commandTimeout,
      resetSuspectedOnSuccess: resetSuspectedOnSuccess,
    );
  }

  @override
  void onDeviceSuspectedOffline() {
    super.onDeviceSuspectedOffline();
    if (_rapidProbeTask != null || boundDevice == null || isDisposed) {
      return;
    }
    _rapidProbeTask = _runRapidProbe().whenComplete(() {
      _rapidProbeTask = null;
    });
  }

  Future<void> _runRapidProbe() async {
    for (var attempt = 0; attempt < _rapidProbeAttempts; attempt++) {
      if (isDisposed || boundDevice == null || !super.isOnline) {
        return;
      }

      try {
        await super.lyfiDeviceApi.getLyfiStatus(boundDevice!.device).timeout(_rapidProbeTimeout);
        super.clearSuspectedOffline();
        await refreshStatus();
        return;
      } on TimeoutException {
        // continue to next attempt
      } on SocketException catch (e, stackTrace) {
        logger?.w('Lyfi rapid probe socket error: $e', error: e, stackTrace: stackTrace);
      } on IOException catch (e, stackTrace) {
        logger?.w('Lyfi rapid probe IO error: $e', error: e, stackTrace: stackTrace);
      } catch (e, stackTrace) {
        logger?.w('Lyfi rapid probe unexpected error: $e', error: e, stackTrace: stackTrace);
      }

      if (attempt < _rapidProbeAttempts - 1) {
        await Future.delayed(_rapidProbeInterval);
      }
    }
  }

  @override
  Future<void> onInitialize() async {
    await super.onInitialize();

    _fanPowerSubscription = super.lyfiThing.fanPowerProperty.value.onUpdate.listen((_) {
      final power = super.lyfiThing.fanPowerProperty.getValue();
      _fanPowerRatio = power.toDouble();
      notifyListeners();
    });

    _temperatureSubscription = super.lyfiThing.temperatureProperty.value.onUpdate.listen((value) {
      _currentTemperature = value;
      notifyListeners();
    });

    _fanModeSubscription = super.lyfiThing.fanModeProperty.value.onUpdate.listen((value) {
      _fanMode = FanMode.values.firstWhere((e) => e.name == value);
      notifyListeners();
    });

    _voltageSubscription = super.lyfiThing.voltageProperty.value.onUpdate.listen((value) {
      super.currentVoltage.value = value;
    });

    _currentSubscription = super.lyfiThing.currentProperty.value.onUpdate.listen((value) {
      currentCurrent.value = value;
    });

    _powerSubscription = super.lyfiThing.powerProperty.value.onUpdate.listen((value) {
      currentWatts.value = value;
    });

    _temporaryDurationSubscription = super.lyfiThing.temporaryDurationProperty.value.onUpdate.listen((value) {
      _temporaryDuration = value;
      notifyListeners();
    });

    _temporaryRemainingSubscription = super.lyfiThing.temporaryRemainingProperty.value.onUpdate.listen((value) {
      _temporaryRemaining = value;
      notifyListeners();
    });

    _stateSubscription = super.lyfiThing.stateProperty.value.onUpdate.listen(_onStateChanged);

    _modeSubscription = super.lyfiThing.modeProperty.value.onUpdate.listen((value) {
      final newMode = LyfiState.fromString(value);
      notifyListeners();
    });

    _sunScheduleSubscription = super.lyfiThing.sunScheduleProperty.value.onUpdate.listen((value) {
      sunInstants
        ..clear()
        ..addAll(value);
      notifyListeners();
    });

    // Set initial values
    _fanPowerRatio = super.lyfiThing.fanPowerProperty.getValue().toDouble();
    _currentTemperature = super.lyfiThing.temperatureProperty.getValue();
    _fanMode = FanMode.values.firstWhere((e) => e.name == super.lyfiThing.fanModeProperty.getValue());
    super.currentVoltage.value = super.lyfiThing.voltageProperty.getValue();
    currentCurrent.value = super.lyfiThing.currentProperty.getValue();
    currentWatts.value = super.lyfiThing.powerProperty.getValue();
    _temporaryDuration = super.lyfiThing.temporaryDurationProperty.getValue();
    _temporaryRemaining = super.lyfiThing.temporaryRemainingProperty.getValue();

    //_channels.length * lyfiBrightnessMax.toDouble();

    await refreshStatus();

    _editorState = _editorState.copyWith(mode: super.mode);

    await _syncScheduleTables(mode: super.mode);

    // Update schedule
    // final schedule = await _deviceApi.getSchedule(boundDevice.device);
    if (!super.isLocked) {
      await _toggleEditor(super.mode);
    }
  }

  @override
  void dispose() {
    //
    if (!_isDisposed) {
      _fanModeSubscription?.cancel();
      _fanPowerSubscription?.cancel();
      _temperatureSubscription?.cancel();
      _voltageSubscription?.cancel();
      _currentSubscription?.cancel();
      _powerSubscription?.cancel();
      _temporaryDurationSubscription?.cancel();
      _temporaryRemainingSubscription?.cancel();
      _stateSubscription?.cancel();
      _modeSubscription?.cancel();
      _sunScheduleSubscription?.cancel();
      for (final cvn in _channels) {
        cvn.dispose();
      }
      if (!super.isLocked && super.isOnline && !isSuspectedOffline) {
        try {
          if (super.state != LyfiState.normal) {
            super.setState(LyfiState.normal);
          }
        } catch (e, stackTrace) {
          logger?.e('Failed to setMode of the device(${super.deviceEntity})', error: e, stackTrace: stackTrace);
        }
      }
      /*
    for (final ch in _channels) {
      ch.dispose();
    }
    */
      if (_editorState.editor != null) {
        _editorState.editor!.dispose();
        _editorState = _editorState.copyWith(editor: null, status: EditorStatus.idle, clearError: true);
      }
      super.dispose();
      _isDisposed = true;
    }
  }

  @override
  Future<void> onDeviceBound() async {
    super.onDeviceBound();

    if (boundDevice == null) {
      return;
    }

    await refreshStatus();

    _editorState = _editorState.copyWith(mode: super.mode);

    await _syncScheduleTables(mode: super.mode);

    // Update schedule
    if (!super.isLocked) {
      await _toggleEditor(super.mode);
    }
  }

  @override
  void onDeviceRemoved() {
    super.onDeviceRemoved();

    for (final cvn in _channels) {
      cvn.dispose();
    }
    _channels.clear();

    _overallBrightness = 0.0;
    _fanPowerRatio = 0.0;
    _fanMode = null;

    if (_editorState.editor != null) {
      _editorState.editor!.dispose();
      _editorState = _editorState.copyWith(editor: null, status: EditorStatus.idle, clearError: true);
    }
  }

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    assert(!_isDisposed);
    if (!super.isOnline || isSuspectedOffline || boundDevice == null) {
      return;
    }
    await super.refreshStatus(cancelToken: cancelToken);

    if (super.isSuspectedOffline) {
      return;
    }

    bool emptyChannels = _channels.isEmpty;
    if (super.lyfiDeviceStatus != null) {
      double ob = 0;
      for (int i = 0; i < lyfiDeviceStatus!.currentColor.length; i++) {
        if (emptyChannels) {
          _channels.add(ValueNotifier<int>(super.lyfiDeviceStatus!.currentColor[i]));
        } else {
          _channels[i].value = super.lyfiDeviceStatus!.currentColor[i];
        }
        ob += lyfiDeviceInfo.channels[i].brightnessRatio * _channels[i].value / lyfiBrightnessMax;
      }
      _overallBrightness = ob;
    }
  }

  Future<void> _syncScheduleTables({required LyfiMode mode, bool force = false}) async {
    if (!super.isOnline || isSuspectedOffline || boundDevice == null) {
      return;
    }

    switch (mode) {
      case LyfiMode.scheduled:
        if (force || scheduledInstants.isEmpty) {
          scheduledInstants
            ..clear()
            ..addAll(lyfiThing.scheduleProperty.value.get());
        }
        break;

      case LyfiMode.sun:
        if (force || sunInstants.isEmpty) {
          sunInstants
            ..clear()
            ..addAll(lyfiThing.sunScheduleProperty.value.get());
        }
        break;

      default:
        break;
    }
  }

  void switchPowerOnOff(bool onOff) {
    if (isSuspectedOffline) {
      notifyAppError('Device is offline. Please retry after reconnection.');
      return;
    }
    super.lyfiThing.onProperty.setValue(onOff);
  }

  bool get canSwitchTemporaryState =>
      !isBusy &&
      !isSuspectedOffline &&
      super.isOn &&
      (super.mode == LyfiMode.scheduled || super.mode == LyfiMode.sun) &&
      (super.state == LyfiState.temporary || super.state == LyfiState.normal);

  void switchTemporaryState() {
    if (!(super.state == LyfiState.normal || super.state == LyfiState.temporary)) {
      throw StateError(gt.translate('Bad device state'));
    }
    // Turn the temp mode on
    if (super.state == LyfiState.normal) {
      super.setState(LyfiState.temporary);
    } else {
      // Restore running mode
      super.setState(LyfiState.normal);
    }
  }

  bool get canSwitchDiscoState =>
      !isBusy &&
      !isSuspectedOffline &&
      super.isOn &&
      (super.state == LyfiState.temporary || super.state == LyfiState.normal);

  void switchDiscoState() async {
    // Turn the disco mode on
    if (super.state == LyfiState.normal || super.state == LyfiState.temporary) {
      super.setState(LyfiState.disco);
    } else {
      // Restore running mode
      super.setState(LyfiState.normal);
    }
  }

  void _scheduleEditorDispose(IEditor editor) {
    Future.delayed(const Duration(milliseconds: 350), () {
      if (_isDisposed) {
        return;
      }
      if (_editorState.editor == editor) {
        return;
      }
      try {
        editor.dispose();
      } catch (e, stackTrace) {
        logger?.w('Editor dispose delayed failed: $e', error: e, stackTrace: stackTrace);
      }
    });
  }

  Future<void> _onStateChanged(String value) async {
    final newState = LyfiState.fromString(value);
    if (newState == LyfiState.dimming) {
      await _toggleEditor(super.mode);
    } else if (newState == LyfiState.normal) {
      final editor = _editorState.editor;
      if (editor != null && editor.isChanged) {
        await editor.save();
        if (editor is ScheduleEditorViewModel) {
          await _syncScheduleTables(mode: LyfiMode.scheduled, force: true);
        } else if (editor is SunEditorViewModel) {
          await _syncScheduleTables(mode: LyfiMode.sun, force: true);
        }
      }
      final previousEditor = _editorState.editor;
      _editorState = _editorState.copyWith(status: EditorStatus.idle, editor: null, clearError: true);
      if (previousEditor != null) {
        _scheduleEditorDispose(previousEditor);
      }
    }
    notifyListeners();
  }

  void toggleLock(bool newIsLocked) {
    if (isSuspectedOffline) {
      return;
    }

    if (newIsLocked) {
      // Exiting edit mode - switch to normal state
      super.setState(LyfiState.normal);
    } else {
      // Entering edit mode - wait for state to change to dimming before creating editor
      super.setState(LyfiState.dimming);
    }
  }

  void switchMode(LyfiMode mode) async {
    await _switchMode(mode);
  }

  Future<void> _switchMode(LyfiMode newMode) async {
    if (isLocked) {
      return;
    }

    if (isSuspectedOffline) {
      notifyAppError('Device is offline. Please retry after reconnection.');
      return;
    }

    if (newMode == LyfiMode.sun) {
      if (borneoDeviceStatus?.timezone.isEmpty ?? true) {
        notifyAppError("Unable to switch to Sun Simulation mode, the device's timezone is not set.");
        return;
      }
      final location = super.lyfiThing.locationProperty.value.get();
      if (location == null) {
        notifyAppError("Unable to switch to Sun Simulation mode, the device's geographic location is not set.");
        return;
      }
    }

    super.setMode(newMode);
    await refreshStatus();
    await _toggleEditor(super.mode);
    notifyListeners();
  }

  Future<void> _toggleEditor(LyfiMode newMode) async {
    final previousEditor = _editorState.editor;
    _editorState = _editorState.copyWith(mode: newMode, status: EditorStatus.loading, editor: null, clearError: true);
    notifyListeners();

    await _syncScheduleTables(mode: newMode);

    IEditor newEditor;
    switch (newMode) {
      case LyfiMode.manual:
        newEditor = ManualEditorViewModel(this);
        break;

      case LyfiMode.scheduled:
        newEditor = ScheduleEditorViewModel(this);
        break;

      case LyfiMode.sun:
        newEditor = SunEditorViewModel(this);
        break;
    }

    try {
      await newEditor.initialize();
      _editorState = _editorState.copyWith(status: EditorStatus.ready, editor: newEditor, clearError: true);
    } catch (e, stackTrace) {
      logger?.e('Failed to initialize editor for mode $newMode', error: e, stackTrace: stackTrace);
      newEditor.dispose();
      _editorState = _editorState.copyWith(status: EditorStatus.error, editor: null, error: e);
    } finally {
      notifyListeners();
    }

    if (previousEditor != null) {
      _scheduleEditorDispose(previousEditor);
    }
    // Do not notify here; callers decide after refresh/creation to notify.
  }

  bool get isDimmingReady => !isLocked && super.state == LyfiState.dimming && _editorState.status == EditorStatus.ready;

  /// Returns a Future that completes when the view model is ready for Dimming editing
  /// (unlocked, state==dimming, editor initialized). No timers/polling are used; it resolves
  /// on the next notifyListeners that satisfies the predicate.
  Future<void> onDimmingReady() async {
    if (isDimmingReady) return;
    final completer = Completer<void>();
    late VoidCallback listener;
    listener = () {
      if (isDimmingReady && !completer.isCompleted) {
        removeListener(listener);
        completer.complete();
      }
    };
    addListener(listener);
    return completer.future;
  }

  Future<SettingsViewModel> loadSettings(final GettextLocalizations gt) async {
    if (!super.isOnline || isSuspectedOffline || boundDevice == null) {
      throw StateError('Device is not reachable at the moment.');
    }
    final vm = SettingsViewModel(
      deviceManager: deviceManager,
      globalEventBus: globalEventBus,
      notification: notification,
      wotThing: wotThing,
      address: deviceEntity.address,
      borneoStatus: borneoDeviceStatus!,
      borneoInfo: super.borneoDeviceInfo!,
      ledInfo: lyfiDeviceInfo,
      ledStatus: lyfiDeviceStatus!,
      powerBehavior: await executeLyfiCommand(() => super.lyfiDeviceApi.getPowerBehavior(boundDevice!.device)),
      location: await executeLyfiCommand(() => super.lyfiDeviceApi.getLocation(boundDevice!.device)),
      gt: gt,
      logger: super.logger,
    );
    await vm.initialize();
    return vm;
  }
}
