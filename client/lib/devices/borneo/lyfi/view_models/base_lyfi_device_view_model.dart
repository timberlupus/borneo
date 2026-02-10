import 'dart:async';
import 'package:borneo_app/devices/borneo/view_models/base_borneo_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/wot/wot_thing.dart';
import 'package:flutter/material.dart';

abstract class BaseLyfiDeviceViewModel extends BaseBorneoDeviceViewModel {
  ILyfiDeviceApi get lyfiDeviceApi => super.boundDevice!.driver as ILyfiDeviceApi;
  LyfiDeviceInfo get lyfiDeviceInfo => lyfiThing.getProperty<LyfiDeviceInfo>('lyfiDeviceInfo')!;

  LyfiDeviceStatus? get lyfiDeviceStatus => lyfiThing.getProperty<LyfiDeviceStatus>('lyfiStatus');

  LyfiThing get lyfiThing => wotThing as LyfiThing;

  double? get nominalPower => lyfiDeviceInfo.nominalPower;
  bool get canMeasureCurrent =>
      super.isOnline && !super.isSuspectedOffline && isOn && lyfiThing.getProperty<double?>('current') != null;

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
  }

  void _subscribeToLyfiThing() {
    _stateSubscription =
        lyfiThing.findProperty('state')?.value.onUpdate.listen((stateName) {
              notifyListeners();
            })
            as StreamSubscription<String>?;
    _modeSubscription =
        lyfiThing.findProperty('mode')?.value.onUpdate.listen((modeName) {
              notifyListeners();
            })
            as StreamSubscription<String>?;

    _statusSubscription =
        lyfiThing.findProperty('lyfiStatus')?.value.onUpdate.listen((status) {
              notifyListeners();
            })
            as StreamSubscription<LyfiDeviceStatus>?;
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

  LyfiMode get mode => LyfiMode.fromString(lyfiThing.getProperty<String>('mode')!);

  void setMode(LyfiMode newMode) {
    if (newMode == this.mode) {
      return;
    }
    lyfiThing.performAction('switchMode', {'mode': newMode.name})!.start();
  }

  LyfiState get state => LyfiState.fromString(lyfiThing.getProperty<String>('state')!);

  void setState(LyfiState newState) {
    if (newState == this.state) {
      return;
    }
    lyfiThing.performAction('switchState', {'state': newState.name})!.start();
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
  void dispose() {
    _unsubscribeFromLyfiThing();
    super.dispose();
  }
}
