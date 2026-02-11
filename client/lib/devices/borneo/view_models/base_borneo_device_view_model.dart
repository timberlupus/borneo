import 'dart:async';

import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/features/devices/view_models/base_device_view_model.dart';
import 'package:borneo_app/core/infrastructure/timezone.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:flutter/material.dart';

abstract class BaseBorneoDeviceViewModel extends BaseDeviceViewModel {
  GeneralBorneoDeviceStatus? get borneoDeviceStatus =>
      isOnline ? wotThing.getProperty<GeneralBorneoDeviceStatus>('generalStatus') : null;

  IBorneoDeviceApi get borneoDeviceApi => super.boundDevice!.driver as IBorneoDeviceApi;

  bool get isOn => wotThing.getProperty<bool>('on')!;

  bool get canMeasureVoltage => super.isOnline && isOn && borneoDeviceStatus?.powerVoltage != null;

  final ValueNotifier<double?> currentVoltage = ValueNotifier<double?>(null);
  final IAppNotificationService notification;

  StreamSubscription? _generalStatusSubscription;
  StreamSubscription? _onOffSubscription;

  @override
  RssiLevel? get rssiLevel =>
      borneoDeviceStatus?.wifiRssi != null ? RssiLevelExtension.fromRssi(borneoDeviceStatus!.wifiRssi!) : null;

  String? get deviceTimezone => wotThing.getProperty<String>('timezone');

  String? _localPosixTimezone;
  String? get localPosixTimezone => _localPosixTimezone;

  bool get hasTimezoneMismatch =>
      deviceTimezone != null && _localPosixTimezone != null && deviceTimezone != _localPosixTimezone;

  BaseBorneoDeviceViewModel({
    required super.deviceManager,
    required super.globalEventBus,
    required this.notification,
    required super.wotThing,
    required super.gt,
    super.logger,
  }) {
    _subscribeToGeneralStatus();
  }

  @override
  @protected
  Future<void> onInitialize() async {
    await _initializeTimezone();
  }

  @override
  void dispose() {
    if (!isDisposed) {
      super.dispose();
      _unsubscribeFromGeneralStatus();
    }
  }

  @override
  void onDeviceBound() {}

  @override
  void onDeviceRemoved() {}

  Future<void> _initializeTimezone() async {
    try {
      final tzc = TimezoneConverter();
      await tzc.init();
      _localPosixTimezone = await tzc.getLocalPosixTimezone();
    } catch (e) {
      logger?.e('Failed to initialize local timezone: $e');
    }
  }

  void _subscribeToGeneralStatus() {
    _generalStatusSubscription = wotThing.findProperty('generalStatus')?.value.onUpdate.listen((status) {
      notifyListeners();
    });

    _onOffSubscription = wotThing.findProperty('on')?.value.onUpdate.listen((value) {
      notifyListeners();
    });
  }

  void _unsubscribeFromGeneralStatus() {
    _generalStatusSubscription?.cancel();
    _generalStatusSubscription = null;
    _onOffSubscription?.cancel();
    _onOffSubscription = null;
  }

  Future<void> syncDeviceTimezone() async {
    final success = await _syncDeviceTimezone();
    if (success) {
      notification.showSuccess('Timezone synchronized successfully');
    } else {
      notification.showError('Failed to sync timezone');
    }
  }

  Future<bool> _syncDeviceTimezone() async {
    if (!super.isOnline || _localPosixTimezone == null) return false;

    try {
      await borneoDeviceApi.setTimeZone(super.boundDevice!.device, _localPosixTimezone!);
      wotThing.findProperty('timezone')?.value.notifyOfExternalUpdate(_localPosixTimezone);
      notifyListeners();
      return true;
    } catch (e) {
      logger?.e('Failed to sync device timezone: $e');
      return false;
    }
  }
}
