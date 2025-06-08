import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/settings_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/sun_editor_view_model.dart';
import 'package:borneo_app/services/i_app_notification_service.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/manual_editor_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/editor/schedule_editor_view_model.dart';

import 'editor/ieditor.dart';

class LyfiViewModel extends BaseLyfiDeviceViewModel {
  static const initializationTimeout = Duration(seconds: 5);
  static const int tempMax = 105;
  static final int tempSetpoint = 45;

  static final DateFormat deviceDateFormat = DateFormat('yyyy-MM-dd HH:mm');

  final IAppNotificationService notification;

  ILyfiDeviceApi get _deviceApi => super.borneoDeviceApi as ILyfiDeviceApi;

  LedRunningMode _mode = LedRunningMode.manual;
  bool _isLocked = true;

  LedRunningMode get mode => _mode;
  bool get isLocked => _isLocked;

  LedState? _ledState;
  LedState? get ledState => _ledState;

  Duration _temporaryDuration = Duration.zero;
  Duration get temporaryDuration => _temporaryDuration;

  final ValueNotifier<Duration> _temporaryRemaining = ValueNotifier<Duration>(Duration.zero);
  ValueNotifier<Duration> get temporaryRemaining => _temporaryRemaining;

  bool get canLockOrUnlock => !isBusy && isOn;
  bool get canUnlock =>
      !isBusy &&
      super.isOnline &&
      isOn &&
      isLocked &&
      (_ledState == LedState.normal || _ledState == LedState.temporary);
  bool get canTimedOn => !isBusy && (!isOn || _mode == LedRunningMode.scheduled);

  IEditor? currentEditor;
  final List<ScheduledInstant> scheduledInstants = [];
  final List<ScheduledInstant> sunInstants = [];

  int? get currentTemp => borneoDeviceStatus?.temperature;
  double get currentTempRatio => (borneoDeviceStatus?.temperature ?? 0).toDouble() / tempMax;

  // LyFi device status and info
  double _fanPowerRatio = 0.0;
  double get fanPowerRatio => _fanPowerRatio;

  double _overallBrightness = 0;
  double get overallBrightness => _overallBrightness;

  final List<ValueNotifier<int>> _channels = [];
  List<ValueNotifier<int>> get channels => _channels;

  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < _channels.length) {
      _channels[index].value = value;
    }
    notifyListeners();
  }

  LyfiViewModel({
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    required this.notification,
    super.logger,
  });

  @override
  Future<void> onInitialize() async {
    if (super.isOnline) {
      _temporaryDuration = await _deviceApi.getTemporaryDuration(boundDevice!.device);
    }

    //_channels.length * lyfiBrightnessMax.toDouble();

    await refreshStatus();

    if (super.isOnline) {
      switch (mode) {
        case LedRunningMode.scheduled:
          scheduledInstants.addAll(await _deviceApi.getSchedule(boundDevice!.device));
          break;

        case LedRunningMode.sun:
          sunInstants.addAll(await _deviceApi.getSunSchedule(boundDevice!.device));
          break;

        default:
          break;
      }
    }

    // Update schedule
    // final schedule = await _deviceApi.getSchedule(boundDevice.device);
    if (!_isLocked) {
      _toggleEditor(_mode);
    }
  }

  @override
  void dispose() {
    //
    for (final cvn in _channels) {
      cvn.dispose();
    }
    if (!_isLocked && super.isOnline) {
      try {
        _deviceApi.switchState(boundDevice!.device, LedState.normal).then((_) {
          _isLocked = true;
        });
      } catch (e, stackTrace) {
        logger?.e('Failed to setMode of the device(${super.deviceEntity})', error: e, stackTrace: stackTrace);
      }
    }
    for (final ch in _channels) {
      ch.dispose();
    }
    super.dispose();
  }

  @override
  Future<void> onDeviceBound() async {
    super.onDeviceBound();

    _temporaryDuration = await _deviceApi.getTemporaryDuration(boundDevice!.device); // TODO add cancallabne

    await refreshStatus();

    switch (mode) {
      case LedRunningMode.scheduled:
        if (scheduledInstants.isEmpty) {
          scheduledInstants.addAll(await _deviceApi.getSchedule(boundDevice!.device));
        }
        break;

      case LedRunningMode.sun:
        if (sunInstants.isEmpty) {
          sunInstants.addAll(await _deviceApi.getSunSchedule(boundDevice!.device));
        }
        break;

      default:
        break;
    }

    // Update schedule
    if (!_isLocked) {
      _toggleEditor(_mode);
    }
  }

  @override
  void onDeviceRemoved() {
    super.onDeviceRemoved();

    for (final cvn in _channels) {
      cvn.dispose();
    }
    _channels.clear();

    _mode = LedRunningMode.manual;
    _ledState = LedState.normal;

    _overallBrightness = 0.0;
    _fanPowerRatio = 0.0;

    _isLocked = true;
    if (currentEditor != null) {
      currentEditor!.dispose();
      currentEditor = null;
    }
  }

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    if (!super.isOnline) {
      return;
    }
    await super.refreshStatus();
    await _fetchDeviceStatus();

    if (_mode == LedRunningMode.sun) {
      final sunSchedule = await _deviceApi.getSunSchedule(boundDevice!.device);
      if (sunSchedule.length == sunInstants.length) {
        for (int i = 0; i < sunSchedule.length; i++) {
          sunInstants[i] = sunSchedule[i];
        }
      }
    }
  }

  Future<void> _fetchDeviceStatus() async {
    if (!super.isOnline) {
      return;
    }

    _ledState = super.lyfiDeviceStatus?.state;
    _isLocked = super.lyfiDeviceStatus?.state.isLocked ?? true;
    _fanPowerRatio = super.lyfiDeviceStatus?.fanPower.toDouble() ?? 0;
    _mode = super.lyfiDeviceStatus?.mode ?? LedRunningMode.manual;

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
  }

  void switchPowerOnOff(bool onOff) {
    super.enqueueUIJob(() => _switchPowerOnOff(onOff));
  }

  Future<void> _switchPowerOnOff(bool onOff) async {
    _deviceApi.setOnOff(super.boundDevice!.device, onOff);
    await refreshStatus();
  }

  bool get canSwitchTemporaryState =>
      !isBusy &&
      super.isOn &&
      (_mode == LedRunningMode.scheduled || _mode == LedRunningMode.sun) &&
      (ledState == LedState.temporary || ledState == LedState.normal);

  void switchTemporaryState() {
    assert(_ledState == LedState.normal || _ledState == LedState.temporary);
    super.enqueueUIJob(() => _switchTemporaryState());
  }

  Future<void> _switchTemporaryState() async {
    // Turn the temp mode on
    if (_ledState == LedState.normal) {
      _deviceApi.switchState(super.boundDevice!.device, LedState.temporary);
    } else {
      // Restore running mode
      _deviceApi.switchState(super.boundDevice!.device, LedState.normal);
    }
    await refreshStatus();
  }

  void toggleLock(bool isLocked) {
    super.enqueueUIJob(() => _toggleLock(isLocked));
  }

  Future<void> toggleLockAsync(bool isLocked) async {
    await _toggleLock(isLocked);
  }

  Future<void> _toggleLock(bool isLocked) async {
    _isLocked = isLocked;

    if (isLocked) {
      assert(currentEditor != null);
      // Exiting the edit mode
      if (currentEditor!.isChanged) {
        await currentEditor!.save();
        if (currentEditor is ScheduleEditorViewModel) {
          scheduledInstants.clear();
          scheduledInstants.addAll(await _deviceApi.getSchedule(boundDevice!.device));
        } else if (currentEditor is SunEditorViewModel) {
          sunInstants.clear();
          sunInstants.addAll(await _deviceApi.getSunSchedule(boundDevice!.device));
        }
      }
    }

    final state = isLocked ? LedState.normal : LedState.dimming;
    await _deviceApi.switchState(super.boundDevice!.device, state);
    _ledState = state;

    if (!isLocked) {
      //Entering edit mode
      _toggleEditor(_mode);
    } else {
      await refreshStatus();
    }
  }

  void switchMode(LedRunningMode mode) {
    super.enqueueUIJob(() => _switchMode(mode));
  }

  Future<void> _switchMode(LedRunningMode mode) async {
    if (isLocked) {
      return;
    }

    if (mode == LedRunningMode.sun) {
      if (borneoDeviceStatus?.timezone.isEmpty ?? true) {
        notifyAppError("Unable to switch to Sun Simulation mode, the device's timezone is not set.");
        return;
      }
      final location = await _deviceApi.getLocation(super.boundDevice!.device);
      if (location == null) {
        notifyAppError("Unable to switch to Sun Simulation mode, the device's geographic location is not set.");
        return;
      }
    }

    await _deviceApi.switchMode(boundDevice!.device, mode);
    mode = await _deviceApi.getMode(boundDevice!.device);
    await _toggleEditor(mode);
    _mode = mode;
    await refreshStatus();
  }

  Future<void> _toggleEditor(LedRunningMode mode) async {
    switch (mode) {
      case LedRunningMode.manual:
        currentEditor = ManualEditorViewModel(this);
        break;

      case LedRunningMode.scheduled:
        currentEditor = ScheduleEditorViewModel(this);
        break;

      case LedRunningMode.sun:
        currentEditor = SunEditorViewModel(this);
        break;
    }
    await currentEditor!.initialize();
  }

  Future<SettingsViewModel> loadSettings() async {
    final vm = SettingsViewModel(
      deviceID: deviceID,
      deviceManager: deviceManager,
      globalEventBus: globalEventBus,
      notification: notification,
      address: deviceEntity.address,
      borneoStatus: borneoDeviceStatus!,
      borneoInfo: super.borneoDeviceInfo!,
      ledInfo: lyfiDeviceInfo,
      ledStatus: lyfiDeviceStatus!,
      powerBehavior: await _deviceApi.getPowerBehavior(boundDevice!.device),
      location: await _deviceApi.getLocation(boundDevice!.device),
    );
    await vm.initialize();
    return vm;
  }
}
