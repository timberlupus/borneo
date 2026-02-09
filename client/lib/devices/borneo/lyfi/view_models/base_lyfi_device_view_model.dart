import 'dart:async';
import 'package:borneo_app/devices/borneo/view_models/base_borneo_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/wot/wot_thing.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/material.dart';

abstract class BaseLyfiDeviceViewModel extends BaseBorneoDeviceViewModel {
  ILyfiDeviceApi get lyfiDeviceApi => super.boundDevice!.driver as ILyfiDeviceApi;
  LyfiDeviceInfo get lyfiDeviceInfo => lyfiDeviceApi.getLyfiInfo(super.boundDevice!.device);

  LyfiDeviceStatus? get lyfiDeviceStatus => lyfiThing.lyfiStatusProperty.value.get();

  LyfiThing get lyfiThing => wotThing as LyfiThing;

  double? get nominalPower => lyfiDeviceInfo.nominalPower;

  bool get canMeasureCurrent =>
      super.isOnline && !super.isSuspectedOffline && isOn && lyfiThing.currentProperty.value.get() != null;

  bool get canMeasurePower => canMeasureCurrent && canMeasureVoltage;

  StreamSubscription<String>? _stateSubscription;
  StreamSubscription<String>? _modeSubscription;
  StreamSubscription<LyfiDeviceStatus>? _statusSubscription;

  final ValueNotifier<double?> currentCurrent = ValueNotifier<double?>(null);
  final ValueNotifier<double?> currentWatts = ValueNotifier<double?>(null);

  @override
  @protected
  Future<void> onInitialize() async {
    super.onInitialize();
    _subscribeToLyfiThing();
    if (super.isOnline) {
      await super.refreshStatus();
    }
  }

  void _subscribeToLyfiThing() {
    _stateSubscription = lyfiThing.stateProperty.value.onUpdate.listen((stateName) {
      final newState = LyfiState.fromString(stateName);
      if (state != newState) {
        notifyListeners();
      }
    });
    _modeSubscription = lyfiThing.modeProperty.value.onUpdate.listen((modeName) {
      final newMode = LyfiMode.fromString(modeName);
      if (mode != newMode) {
        notifyListeners();
      }
    });

    _statusSubscription = lyfiThing.lyfiStatusProperty.value.onUpdate.listen((status) {
      notifyListeners();
    });
  }

  @override
  void onDeviceBound() {
    super.onDeviceBound();
    if (lyfiThing.isOffline && boundDevice != null) {
      final borneoApi = boundDevice!.api<IBorneoDeviceApi>();
      final lyfiApi = boundDevice!.api<ILyfiDeviceApi>();
      lyfiThing.bindToOnlineApis(borneoApi, lyfiApi);
    }
    _subscribeToLyfiThing();
  }

  @override
  void onDeviceRemoved() {
    super.onDeviceRemoved();
    _unsubscribeFromLyfiThing();
  }

  void _unsubscribeFromLyfiThing() {
    _stateSubscription?.cancel();
    _stateSubscription = null;
    _modeSubscription?.cancel();
    _modeSubscription = null;
    _statusSubscription?.cancel();
    _statusSubscription = null;
  }

  LyfiMode get mode => LyfiMode.fromString(lyfiThing.modeProperty.value.get());

  void setMode(LyfiMode newMode) {
    if (newMode == this.mode) {
      return;
    }
    try {
      lyfiThing.performAction('switchMode', {'mode': newMode.name})!.start();
    } catch (_) {
      rethrow;
    }
  }

  LyfiState get state => LyfiState.fromString(lyfiThing.stateProperty.value.get());

  void setState(LyfiState newState) {
    if (newState == this.state) {
      return;
    }
    try {
      lyfiThing.performAction('switchState', {'state': newState.name})!.start();
    } catch (_) {
      rethrow;
    }
  }

  bool get isLocked => state.isLocked;

  BaseLyfiDeviceViewModel({
    required super.deviceManager,
    required super.globalEventBus,
    required super.notification,
    required super.wotThing,
    required super.gt,
    super.logger,
  });

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    await super.refreshStatus(cancelToken: cancelToken);
  }

  @override
  void dispose() {
    _unsubscribeFromLyfiThing();
    super.dispose();
  }
}
