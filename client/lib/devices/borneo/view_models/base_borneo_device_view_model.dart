import 'package:borneo_app/view_models/devices/base_device_view_model.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';

abstract class BaseBorneoDeviceViewModel extends BaseDeviceViewModel {
  GeneralBorneoDeviceInfo? _borneoDeviceInfo;
  GeneralBorneoDeviceInfo? get borneoDeviceInfo => _borneoDeviceInfo;

  GeneralBorneoDeviceStatus? _borneoDeviceStatus;
  GeneralBorneoDeviceStatus? get borneoDeviceStatus => isOnline ? _borneoDeviceStatus : null;

  IBorneoDeviceApi get borneoDeviceApi => super.boundDevice!.driver as IBorneoDeviceApi;

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
  Future<void> loadDeviceInfo({CancellationToken? cancelToken}) async {
    _borneoDeviceInfo = await borneoDeviceApi.getGeneralDeviceInfo(super.boundDevice!.device);
  }

  @override
  Future<void> refreshStatus({CancellationToken? cancelToken}) async {
    _borneoDeviceStatus = await borneoDeviceApi.getGeneralDeviceStatus(super.boundDevice!.device);
  }
}
