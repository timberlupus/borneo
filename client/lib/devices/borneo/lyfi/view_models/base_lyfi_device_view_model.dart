import 'package:borneo_app/devices/borneo/view_models/base_borneo_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';

abstract class BaseLyfiDeviceViewModel extends BaseBorneoDeviceViewModel {
  ILyfiDeviceApi get lyfiDeviceApi => super.boundDevice!.driver as ILyfiDeviceApi;

  BaseLyfiDeviceViewModel({required super.deviceID, required super.deviceManager, required super.globalEventBus});
}
