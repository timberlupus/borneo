import 'dart:async';

import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/features/devices/view_models/base_device_view_model.dart';
import 'package:borneo_app/core/infrastructure/timezone.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/material.dart';

abstract class BaseBorneoDeviceViewModel extends BaseDeviceViewModel {
  GeneralBorneoDeviceInfo? get borneoDeviceInfo => borneoDeviceApi.getGeneralDeviceInfo(boundDevice!.device);

  GeneralBorneoDeviceStatus? get borneoDeviceStatus =>
      isOnline ? wotThing.getProperty<GeneralBorneoDeviceStatus>('generalStatus') : null;

  IBorneoDeviceApi get borneoDeviceApi => super.boundDevice!.driver as IBorneoDeviceApi;

  DateTime get deviceClock => borneoDeviceStatus!.timestamp.toLocal();

  bool _isOn = false;
  bool get isOn => _isOn;

  bool get canMeasureVoltage => super.isOnline && isOn && borneoDeviceStatus?.powerVoltage != null;

  final ValueNotifier<double?> currentVoltage = ValueNotifier<double?>(null);
  final IAppNotificationService notification;

  StreamSubscription? _generalStatusSubscription;

  @override
  RssiLevel? get rssiLevel =>
      borneoDeviceStatus?.wifiRssi != null ? RssiLevelExtension.fromRssi(borneoDeviceStatus!.wifiRssi!) : null;

  String? _deviceTimezone;
  String? get deviceTimezone => _deviceTimezone;

  String? _localPosixTimezone;
  String? get localPosixTimezone => _localPosixTimezone;

  bool get hasTimezoneMismatch =>
      _deviceTimezone != null && _localPosixTimezone != null && _deviceTimezone != _localPosixTimezone;

  BaseBorneoDeviceViewModel({
    required super.deviceManager,
    required super.globalEventBus,
    required this.notification,
    required super.wotThing,
    super.logger,
  });

  @override
  @protected
  Future<void> onInitialize() async {
    // await super.onInitialize();
    await _initializeTimezone();
  }

  @override
  void onDeviceBound() {
    _subscribeToGeneralStatus();
  }

  @override
  void onDeviceRemoved() {
    _unsubscribeFromGeneralStatus();
  }

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
    final property = wotThing.findProperty('generalStatus');
    if (property != null) {
      _generalStatusSubscription = property.value.onUpdate.listen((status) {
        notifyListeners();
      });
    }
  }

  void _unsubscribeFromGeneralStatus() {
    _generalStatusSubscription?.cancel();
    _generalStatusSubscription = null;
  }

  Future<void> checkDeviceTimezone() async {
    if (!super.isOnline || _localPosixTimezone == null) return;

    try {
      final status = await borneoDeviceApi.getGeneralDeviceStatus(super.boundDevice!.device);
      _deviceTimezone = status.timezone;
      notifyListeners();
    } catch (e) {
      logger?.e('Failed to check device timezone: $e');
    }
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
      _deviceTimezone = _localPosixTimezone;
      notifyListeners();
      return true;
    } catch (e) {
      logger?.e('Failed to sync device timezone: $e');
      return false;
    }
  }

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    if (!super.isOnline) {
      return;
    }

    final oldIsOn = _isOn;
    final oldTimezone = _deviceTimezone;
    final oldVoltage = currentVoltage.value;

    final status = await borneoDeviceApi.getGeneralDeviceStatus(super.boundDevice!.device, cancelToken: cancelToken);
    _isOn = status.power;
    _deviceTimezone = status.timezone;

    // Only notify if something actually changed
    if (_isOn != oldIsOn || _deviceTimezone != oldTimezone || currentVoltage.value != oldVoltage) {
      notifyListeners();
    }
  }
}
