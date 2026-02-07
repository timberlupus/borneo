import 'package:borneo_app/devices/borneo/view_models/base_borneo_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/wot/wot_thing.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/material.dart';

abstract class BaseLyfiDeviceViewModel extends BaseBorneoDeviceViewModel {
  LyfiDeviceStatus? _lyfiStatus;

  ILyfiDeviceApi get lyfiDeviceApi => super.boundDevice!.driver as ILyfiDeviceApi;
  LyfiDeviceInfo get lyfiDeviceInfo => lyfiDeviceApi.getLyfiInfo(super.boundDevice!.device);

  LyfiDeviceStatus? get lyfiDeviceStatus => _lyfiStatus;

  LyfiThing? get lyfiThing => wotThing as LyfiThing?;

  double? get nominalPower => lyfiDeviceInfo.nominalPower;

  bool get canMeasureCurrent =>
      super.isOnline && !super.isSuspectedOffline && isOn && lyfiDeviceStatus?.powerCurrent != null;
  bool get canMeasurePower => canMeasureCurrent && canMeasureVoltage;

  LyfiMode _mode = LyfiMode.manual;
  LyfiState _state = LyfiState.normal;

  final ValueNotifier<double?> currentCurrent = ValueNotifier<double?>(null);
  final ValueNotifier<double?> currentWatts = ValueNotifier<double?>(null);

  @override
  @protected
  Future<void> onInitialize() async {
    super.onInitialize();
    if (super.isOnline) {
      await super.refreshStatus();
    }
  }

  LyfiMode get mode => _mode;

  Future<void> setMode(LyfiMode newMode) async {
    if (newMode == _mode) {
      return;
    }
    try {
      await runDeviceCommand(() => lyfiDeviceApi.switchMode(super.boundDevice!.device, newMode));
      _mode = newMode;
    } catch (_) {
      await refreshStatus();
      rethrow;
    }
  }

  LyfiState get state => _state;

  Future<void> setState(LyfiState newState) async {
    if (newState == _state) {
      return;
    }
    try {
      await runDeviceCommand(() => lyfiDeviceApi.switchState(super.boundDevice!.device, newState));
      _state = newState;
    } catch (_) {
      await refreshStatus();
      rethrow;
    }
  }

  bool get isLocked => state.isLocked;

  BaseLyfiDeviceViewModel({
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    required super.notification,
    super.logger,
  });

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    await super.refreshStatus(cancelToken: cancelToken);

    if (!super.isOnline || super.isSuspectedOffline) {
      return;
    }

    final oldMode = _mode;
    final oldState = _state;
    final oldCurrent = currentCurrent.value;

    _lyfiStatus = await lyfiDeviceApi.getLyfiStatus(boundDevice!.device, cancelToken: cancelToken);
    _mode = _lyfiStatus?.mode ?? LyfiMode.manual;
    _state = _lyfiStatus?.state ?? LyfiState.normal;

    currentCurrent.value = _lyfiStatus?.powerCurrent;
    currentWatts.value = currentVoltage.value != null && currentCurrent.value != null
        ? currentVoltage.value! * currentCurrent.value!
        : null;

    // Only notify if something actually changed
    if (_mode != oldMode || _state != oldState || currentCurrent.value != oldCurrent) {
      notifyListeners();
    }
  }
}
