import 'package:borneo_app/devices/borneo/view_models/base_borneo_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';

abstract class BaseLyfiDeviceViewModel extends BaseBorneoDeviceViewModel {
  ILyfiDeviceApi get lyfiDeviceApi => super.boundDevice!.driver as ILyfiDeviceApi;

  BaseLyfiDeviceViewModel(super.deviceID, super.deviceManager, {required super.globalEventBus});
}
