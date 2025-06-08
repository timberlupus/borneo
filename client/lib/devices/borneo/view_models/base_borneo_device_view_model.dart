import 'package:borneo_app/view_models/devices/base_device_view_model.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter/material.dart';
import 'package:synchronized/synchronized.dart';

abstract class BaseBorneoDeviceViewModel extends BaseDeviceViewModel {
  GeneralBorneoDeviceInfo? get borneoDeviceInfo => borneoDeviceApi.getGeneralDeviceInfo(boundDevice!.device);

  final _lock = Lock();
  GeneralBorneoDeviceStatus? _borneoDeviceStatus;
  GeneralBorneoDeviceStatus? get borneoDeviceStatus => isOnline ? _borneoDeviceStatus : null;

  IBorneoDeviceApi get borneoDeviceApi => super.boundDevice!.driver as IBorneoDeviceApi;

  DateTime get deviceClock => borneoDeviceStatus!.timestamp.toLocal();

  bool _isOn = false;
  bool get isOn => _isOn;

  bool get canMeasureCurrent => super.isOnline && isOn && borneoDeviceStatus?.powerCurrent != null;
  bool get canMeasureVoltage => super.isOnline && isOn && borneoDeviceStatus?.powerVoltage != null;
  bool get canMeasurePower => canMeasureCurrent && canMeasureVoltage;

  final ValueNotifier<double?> currentVoltage = ValueNotifier<double?>(null);
  final ValueNotifier<double?> currentCurrent = ValueNotifier<double?>(null);
  final ValueNotifier<double?> currentWatts = ValueNotifier<double?>(null);

  @override
  RssiLevel? get rssiLevel =>
      _borneoDeviceStatus?.wifiRssi != null ? RssiLevelExtension.fromRssi(_borneoDeviceStatus!.wifiRssi!) : null;

  BaseBorneoDeviceViewModel({
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    super.logger,
  });

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    await _lock
        .synchronized(() async {
          _borneoDeviceStatus = await borneoDeviceApi.getGeneralDeviceStatus(super.boundDevice!.device);
          _isOn = borneoDeviceStatus!.power;

          currentVoltage.value = _borneoDeviceStatus?.powerVoltage;
          currentCurrent.value = _borneoDeviceStatus?.powerCurrent;
          currentWatts.value =
              currentVoltage.value != null && currentCurrent.value != null
                  ? (currentVoltage.value! / 1000.0) * (currentCurrent.value! / 1000.0)
                  : null;
        })
        .asCancellable(cancelToken);
  }
}
