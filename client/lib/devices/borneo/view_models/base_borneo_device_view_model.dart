import 'package:borneo_app/view_models/devices/base_device_view_model.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';

abstract class BaseBorneoDeviceViewModel extends BaseDeviceViewModel {
  GeneralBorneoDeviceStatus? _borneoDeviceStatus;
  GeneralBorneoDeviceStatus? get borneoDeviceStatus => _borneoDeviceStatus;

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
  Future<void> refreshStatus() async {
    _borneoDeviceStatus = await borneoDeviceApi.getGeneralDeviceStatus(super.boundDevice!.device);
  }
}
