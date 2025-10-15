import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/features/devices/view_models/base_device_view_model.dart';
import 'package:borneo_app/core/infrastructure/timezone.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/material.dart';

abstract class BaseBorneoDeviceViewModel extends BaseDeviceViewModel {
  GeneralBorneoDeviceInfo? get borneoDeviceInfo => borneoDeviceApi.getGeneralDeviceInfo(boundDevice!.device);

  GeneralBorneoDeviceStatus? _borneoDeviceStatus;
  GeneralBorneoDeviceStatus? get borneoDeviceStatus => isOnline ? _borneoDeviceStatus : null;

  IBorneoDeviceApi get borneoDeviceApi => super.boundDevice!.driver as IBorneoDeviceApi;

  DateTime get deviceClock => borneoDeviceStatus!.timestamp.toLocal();

  bool _isOn = false;
  bool get isOn => _isOn;

  bool get canMeasureVoltage => super.isOnline && isOn && borneoDeviceStatus?.powerVoltage != null;

  final ValueNotifier<double?> currentVoltage = ValueNotifier<double?>(null);
  final IAppNotificationService notification;

  @override
  RssiLevel? get rssiLevel =>
      _borneoDeviceStatus?.wifiRssi != null ? RssiLevelExtension.fromRssi(_borneoDeviceStatus!.wifiRssi!) : null;

  String? _deviceTimezone;
  String? get deviceTimezone => _deviceTimezone;

  String? _localPosixTimezone;
  String? get localPosixTimezone => _localPosixTimezone;

  bool get hasTimezoneMismatch =>
      _deviceTimezone != null && _localPosixTimezone != null && _deviceTimezone != _localPosixTimezone;

  BaseBorneoDeviceViewModel({
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    required this.notification,
    super.logger,
  });

  @override
  Future<void> onInitialize() async {
    // await super.onInitialize();
    await _initializeTimezone();
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

    _borneoDeviceStatus = await borneoDeviceApi.getGeneralDeviceStatus(
      super.boundDevice!.device,
      cancelToken: cancelToken,
    );
    _isOn = borneoDeviceStatus!.power;
    _deviceTimezone = _borneoDeviceStatus?.timezone;

    currentVoltage.value = _borneoDeviceStatus?.powerVoltage;
  }
}
