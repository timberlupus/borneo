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
  bool _schedulerEnabled = true;
  bool _isLocked = true;

  bool get isOn => _isOn;
  bool get schedulerEnabled => _schedulerEnabled;
  bool get isLocked => _isLocked;

  LedState? _ledState;
  LedState? get ledState => _ledState;

  double get currentWatts => (borneoDeviceStatus?.powerCurrent ?? 0) * (borneoDeviceStatus?.powerVoltage ?? 0);

  Duration _nightlightRemaining = Duration.zero;
  Duration get nightlightRemaining => _nightlightRemaining;

  bool get canLockOrUnlock => !isBusy && isOn;
  bool get canUnlock => !isBusy && isOnline && isOn && isLocked;
  bool get canTimedOn => !isBusy && (!isOn || schedulerEnabled);
  bool get canToggleManualMode => !isBusy && isOn && !isLocked;

  IEditor? currentEditor;
  final List<ScheduledInstant> scheduledInstants = [];

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

  double get maxOverallBrightness => _channels.length * 1000.0;

  final List<ValueNotifier<int>> _channels = [];
  List<ValueNotifier<int>> get channels => _channels;

  Future<void> updateChannelValue(int index, int value) async {
    if (index >= 0 && index < _channels.length) {
      _channels[index].value = value;
    }
    notifyListeners();
  }

  LyfiViewModel(super.deviceID, super.deviceManager, {required super.globalEventBus, super.logger}) {
    //
  }

  @override
  Future<void> onInitialize() async {
    scheduledInstants.addAll(await _deviceApi.getSchedule(boundDevice!.device));

    for (int i = 0; i < lyfiDeviceInfo.channels.length; i++) {
      _channels.add(ValueNotifier(0));
    }

    // Update schedule
    // final schedule = await _deviceApi.getSchedule(boundDevice.device);
    if (!_isLocked) {
      _toggleEditor(schedulerEnabled);
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
    await super.refreshStatus();
    await _fetchDeviceStatus();
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
      _schedulerEnabled = lyfiDeviceStatus!.schedulerEnabled;
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
      !isBusy && _isOn && schedulerEnabled && (ledState == LedState.nightlight || ledState == LedState.normal);

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

  Future<void> _toggleLock(bool isLocked) async {
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
    _isLocked = isLocked;

    if (!isLocked) {
      //Entering edit mode
      _toggleEditor(schedulerEnabled);
    }
  }

  void switchSchedulerEnabled(bool enabled) {
    super.enqueueUIJob(() => _switchSchedulerEnabled(enabled));
  }

  Future<void> _switchSchedulerEnabled(bool enabled) async {
    if (isLocked) {
      return;
    }
    await _deviceApi.setSchedulerEnabled(boundDevice!.device, enabled);
    _toggleEditor(enabled);
    _schedulerEnabled = enabled;
  }

  Future<void> _toggleEditor(bool isSchedulerEnabled) async {
    assert(!isLocked);
    if (isSchedulerEnabled) {
      currentEditor = ScheduleEditorViewModel(this);
    } else {
      currentEditor = ManualEditorViewModel(this);
    }
    await currentEditor!.initialize();
  }
}
