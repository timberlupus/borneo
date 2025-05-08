import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/settings_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/sun_editor_view_model.dart';
import 'package:borneo_app/devices/borneo/view_models/base_borneo_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/manual_editor_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/schedule_editor_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';

import 'ieditor.dart';

class LyfiViewModel extends BaseBorneoDeviceViewModel {
  static const initializationTimeout = Duration(seconds: 5);
  static const int tempMax = 105;
  static final int tempSetpoint = 45;

  static final DateFormat deviceDateFormat = DateFormat('yyyy-MM-dd HH:mm');

  ILyfiDeviceApi get _deviceApi => super.borneoDeviceApi as ILyfiDeviceApi;

  bool _isOn = false;
  LedRunningMode _mode = LedRunningMode.manual;
  bool _isLocked = true;

  bool get isOn => _isOn;
  LedRunningMode get mode => _mode;
  bool get isLocked => _isLocked;

  LedState? _ledState;
  LedState? get ledState => _ledState;

  double get currentWatts => (borneoDeviceStatus?.powerCurrent ?? 0) * (borneoDeviceStatus?.powerVoltage ?? 0);

  Duration _nightlightRemaining = Duration.zero;
  Duration get nightlightRemaining => _nightlightRemaining;

  bool get canLockOrUnlock => !isBusy && isOn;
  bool get canUnlock => !isBusy && isOnline && isOn && isLocked;
  bool get canTimedOn => !isBusy && (!isOn || _mode == LedRunningMode.scheduled);

  IEditor? currentEditor;
  final List<ScheduledInstant> scheduledInstants = [];
  final List<ScheduledInstant> sunInstants = [];

  // Borneo device general status and info
  GeneralBorneoDeviceInfo get borneoDeviceInfo => _deviceApi.getGeneralDeviceInfo(super.boundDevice!.device);

  LyfiDeviceStatus? _lyfiDeviceStatus;
  LyfiDeviceStatus? get lyfiDeviceStatus => _lyfiDeviceStatus;

  int? get currentTemp => borneoDeviceStatus?.temperature;
  double get currentTempRatio => (borneoDeviceStatus?.temperature ?? 0).toDouble() / tempMax;

  // LyFi device status and info
  LyfiDeviceInfo get lyfiDeviceInfo => _deviceApi.getLyfiInfo(super.boundDevice!.device);

  double _fanPowerRatio = 0.0;
  double get fanPowerRatio => _fanPowerRatio;

  double get overallBrightness {
    int sum = 0;
    for (final v in _channels) {
      sum += v.value;
    }
    return sum.toDouble();
  }

  double get maxOverallBrightness => _channels.length * lyfiBrightnessMax.toDouble();

  final List<ValueNotifier<int>> _channels = [];
  List<ValueNotifier<int>> get channels => _channels;

  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < _channels.length) {
      _channels[index].value = value;
    }
    notifyListeners();
  }

  LyfiViewModel({required super.deviceID, required super.deviceManager, required super.globalEventBus, super.logger}) {
    //
  }

  @override
  Future<void> onInitialize() async {
    for (int i = 0; i < lyfiDeviceInfo.channels.length; i++) {
      _channels.add(ValueNotifier(0));
    }

    await refreshStatus();

    if (_mode == LedRunningMode.scheduled) {
      scheduledInstants.addAll(await _deviceApi.getSchedule(boundDevice!.device));
    } else if (_mode == LedRunningMode.sun) {
      sunInstants.addAll(await _deviceApi.getSunSchedule(boundDevice!.device));
    } else {
      // do nothing
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
    if (!_isLocked && isOnline) {
      try {
        _deviceApi.switchState(boundDevice!.device, LedState.normal).then((_) {
          _isLocked = true;
        });
      } catch (e, stackTrace) {
        logger?.e('Failed to setMode of the device(${super.deviceEntity})', error: e, stackTrace: stackTrace);
      }
    }
    super.dispose();
  }

  @override
  Future<void> refreshStatus() async {
    if (!isOnline) {
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
    if (!isOnline) {
      return;
    }

    _lyfiDeviceStatus = await _deviceApi.getLyfiStatus(super.boundDevice!.device);

    _isOn = borneoDeviceStatus!.power;
    if (_lyfiDeviceStatus != null) {
      _ledState = _lyfiDeviceStatus!.state;
      _isLocked = lyfiDeviceStatus!.state.isLocked;
      _fanPowerRatio = lyfiDeviceStatus!.fanPower.toDouble();
      _mode = lyfiDeviceStatus!.mode;
    }

    _nightlightRemaining = lyfiDeviceStatus!.nightlightRemaining;

    for (int i = 0; i < lyfiDeviceStatus!.currentColor.length; i++) {
      _channels[i].value = lyfiDeviceStatus!.currentColor[i];
    }
  }

  void switchPowerOnOff(bool onOff) {
    super.enqueueUIJob(() => _switchPowerOnOff(onOff));
  }

  Future<void> _switchPowerOnOff(bool onOff) async {
    _deviceApi.setOnOff(super.boundDevice!.device, onOff);
    await refreshStatus();
    _isOn = onOff;
  }

  bool get canSwitchNightlightState =>
      !isBusy &&
      _isOn &&
      (_mode == LedRunningMode.scheduled || _mode == LedRunningMode.sun) &&
      (ledState == LedState.nightlight || ledState == LedState.normal || ledState == LedState.poweringOn);

  void switchNightlightState() {
    if (_ledState == LedState.normal || _ledState == LedState.nightlight) {
      super.enqueueUIJob(() => _switchNightlightState());
    }
  }

  Future<void> _switchNightlightState() async {
    // Turn the temp mode on
    if (_ledState == LedState.normal) {
      _deviceApi.switchState(super.boundDevice!.device, LedState.nightlight);
      _ledState = LedState.nightlight;
    } else {
      // Restore running mode
      _deviceApi.switchState(super.boundDevice!.device, LedState.normal);
      _ledState = LedState.normal;
    }
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
        }
      }
    }

    final state = isLocked ? LedState.normal : LedState.dimming;
    await _deviceApi.switchState(super.boundDevice!.device, state);

    if (!isLocked) {
      //Entering edit mode
      _toggleEditor(_mode);
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
    _toggleEditor(mode);
    _mode = mode;
  }

  Future<void> _toggleEditor(LedRunningMode mode) async {
    assert(!isLocked);
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
      address: deviceEntity.address,
      borneoStatus: borneoDeviceStatus!,
      borneoInfo: borneoDeviceInfo,
      ledInfo: lyfiDeviceInfo,
      ledStatus: lyfiDeviceStatus!,
      powerBehavior: await _deviceApi.getPowerBehavior(boundDevice!.device),
      location: await _deviceApi.getLocation(boundDevice!.device),
    );
    await vm.initialize();
    return vm;
  }
}
