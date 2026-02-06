import 'dart:async';
import 'dart:io';
import 'package:borneo_app/core/services/local_service.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/settings_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/sun_editor_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
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

  ILyfiDeviceApi get _deviceApi => super.borneoDeviceApi as ILyfiDeviceApi;

  Duration _temporaryDuration = Duration.zero;
  Duration get temporaryDuration => _temporaryDuration;

  final ValueNotifier<Duration> _temporaryRemaining = ValueNotifier<Duration>(Duration.zero);
  ValueNotifier<Duration> get temporaryRemaining => _temporaryRemaining;

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

  int? get currentTempRaw => super.lyfiDeviceStatus?.temperature;
  int? get currentTemp => super.lyfiDeviceStatus?.temperature == null
      ? null
      : localeService.convertTemperatureValue(super.lyfiDeviceStatus!.temperature!.toDouble()).toInt();

  String get temperatureUnitText => localeService.temperatureUnitText;

  // LyFi device status and info
  double? _fanPowerRatio = 0.0;
  double? get fanPowerRatio => _fanPowerRatio;

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
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    required super.notification,
    required this.localeService,
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
        await _deviceApi.getLyfiStatus(boundDevice!.device).timeout(_rapidProbeTimeout);
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
    if (super.isOnline && !isSuspectedOffline && boundDevice != null) {
      _temporaryDuration = await executeLyfiCommand(() => _deviceApi.getTemporaryDuration(boundDevice!.device));
    }

    //_channels.length * lyfiBrightnessMax.toDouble();

    await refreshStatus();

    _editorState = _editorState.copyWith(mode: super.mode);

    if (super.isOnline && !isSuspectedOffline && boundDevice != null) {
      switch (mode) {
        case LyfiMode.scheduled:
          scheduledInstants.addAll(await executeLyfiCommand(() => _deviceApi.getSchedule(boundDevice!.device)));
          break;

        case LyfiMode.sun:
          sunInstants.addAll(await executeLyfiCommand(() => _deviceApi.getSunSchedule(boundDevice!.device)));
          break;

        default:
          break;
      }
    }

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
      for (final cvn in _channels) {
        cvn.dispose();
      }
      if (!super.isLocked && super.isOnline && !isSuspectedOffline) {
        try {
          Future.microtask(() async {
            if (super.state != LyfiState.normal) {
              await super.setState(LyfiState.normal);
            }
          });
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

    _temporaryDuration = await executeLyfiCommand(() => _deviceApi.getTemporaryDuration(boundDevice!.device));

    await refreshStatus();

    _editorState = _editorState.copyWith(mode: super.mode);

    switch (mode) {
      case LyfiMode.scheduled:
        if (scheduledInstants.isEmpty) {
          scheduledInstants.addAll(await executeLyfiCommand(() => _deviceApi.getSchedule(boundDevice!.device)));
        }
        break;

      case LyfiMode.sun:
        if (sunInstants.isEmpty) {
          sunInstants.addAll(await executeLyfiCommand(() => _deviceApi.getSunSchedule(boundDevice!.device)));
        }
        break;

      default:
        break;
    }

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

    _fanPowerRatio = super.lyfiDeviceStatus?.fanPower == null ? null : super.lyfiDeviceStatus!.fanPower!.toDouble();

    _temporaryRemaining.value = lyfiDeviceStatus?.temporaryRemaining ?? Duration.zero;

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

    if (super.mode == LyfiMode.sun) {
      final sunSchedule = await _deviceApi.getSunSchedule(boundDevice!.device, cancelToken: cancelToken);
      if (sunSchedule.length == sunInstants.length) {
        for (int i = 0; i < sunSchedule.length; i++) {
          sunInstants[i] = sunSchedule[i];
        }
      }
    }
  }

  void switchPowerOnOff(bool onOff) async {
    if (isSuspectedOffline) {
      notifyAppError('Device is offline. Please retry after reconnection.');
      return;
    }
    await _switchPowerOnOff(onOff);
  }

  Future<void> _switchPowerOnOff(bool onOff) async {
    await executeLyfiCommand(() => _deviceApi.setOnOff(super.boundDevice!.device, onOff));
    await refreshStatus();
  }

  bool get canSwitchTemporaryState =>
      !isBusy &&
      !isSuspectedOffline &&
      super.isOn &&
      (super.mode == LyfiMode.scheduled || super.mode == LyfiMode.sun) &&
      (super.state == LyfiState.temporary || super.state == LyfiState.normal);

  void switchTemporaryState() async {
    assert(super.state == LyfiState.normal || super.state == LyfiState.temporary);
    await _switchTemporaryState();
  }

  Future<void> _switchTemporaryState() async {
    // Turn the temp mode on
    if (super.state == LyfiState.normal) {
      await executeLyfiCommand(() => _deviceApi.switchState(super.boundDevice!.device, LyfiState.temporary));
    } else {
      // Restore running mode
      await executeLyfiCommand(() => _deviceApi.switchState(super.boundDevice!.device, LyfiState.normal));
    }
    await refreshStatus();
  }

  bool get canSwitchDiscoState =>
      !isBusy &&
      !isSuspectedOffline &&
      super.isOn &&
      (super.state == LyfiState.temporary || super.state == LyfiState.normal);

  void switchDiscoState() async {
    await _switchDiscoState();
  }

  Future<void> _switchDiscoState() async {
    // Turn the disco mode on
    if (super.state == LyfiState.normal || super.state == LyfiState.temporary) {
      await executeLyfiCommand(() => _deviceApi.switchState(super.boundDevice!.device, LyfiState.disco));
    } else {
      // Restore running mode
      await executeLyfiCommand(() => _deviceApi.switchState(super.boundDevice!.device, LyfiState.normal));
    }
    await refreshStatus();
  }

  void toggleLock(bool isLocked) async {
    await _toggleLock(isLocked);
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

  Future<void> _toggleLock(bool newIsLocked) async {
    if (isSuspectedOffline) {
      return;
    }
    if (!super.isLocked) {
      final editor = _editorState.editor;
      assert(editor != null);
      // Exiting the edit mode
      if (editor != null && editor.isChanged) {
        await editor.save();
        if (editor is ScheduleEditorViewModel) {
          scheduledInstants.clear();
          scheduledInstants.addAll(await executeLyfiCommand(() => _deviceApi.getSchedule(boundDevice!.device)));
        } else if (editor is SunEditorViewModel) {
          sunInstants.clear();
          sunInstants.addAll(await executeLyfiCommand(() => _deviceApi.getSunSchedule(boundDevice!.device)));
        }
      }
    }

    if (newIsLocked) {
      // Exiting edit mode - switch to normal state
      await super.setState(LyfiState.normal);
      await refreshStatus();
      final previousEditor = _editorState.editor;
      _editorState = _editorState.copyWith(status: EditorStatus.idle, editor: null, clearError: true);
      if (previousEditor != null) {
        _scheduleEditorDispose(previousEditor);
      }
      notifyListeners();
    } else {
      // Entering edit mode - wait for state to change to dimming before creating editor
      await super.setState(LyfiState.dimming);
      await refreshStatus();

      await _toggleEditor(super.mode);
      // Notify listeners so UI awaiting readiness can proceed
      notifyListeners();
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
      final location = await executeLyfiCommand(() => _deviceApi.getLocation(super.boundDevice!.device));
      if (location == null) {
        notifyAppError("Unable to switch to Sun Simulation mode, the device's geographic location is not set.");
        return;
      }
    }

    await super.setMode(newMode);
    await refreshStatus();
    await _toggleEditor(super.mode);
    notifyListeners();
  }

  Future<void> _toggleEditor(LyfiMode newMode) async {
    final previousEditor = _editorState.editor;
    _editorState = _editorState.copyWith(mode: newMode, status: EditorStatus.loading, editor: null, clearError: true);
    notifyListeners();

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
      gt,
      deviceID: deviceID,
      deviceManager: deviceManager,
      globalEventBus: globalEventBus,
      notification: notification,
      address: deviceEntity.address,
      borneoStatus: borneoDeviceStatus!,
      borneoInfo: super.borneoDeviceInfo!,
      ledInfo: lyfiDeviceInfo,
      ledStatus: lyfiDeviceStatus!,
      powerBehavior: await executeLyfiCommand(() => _deviceApi.getPowerBehavior(boundDevice!.device)),
      location: await executeLyfiCommand(() => _deviceApi.getLocation(boundDevice!.device)),
    );
    await vm.initialize();
    return vm;
  }
}
