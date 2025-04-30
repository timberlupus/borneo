
import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';

class SettingsViewModel extends BaseViewModel {
  final Uri address;
  final GeneralBorneoDeviceStatus borneoStatus;
  final GeneralBorneoDeviceInfo borneoInfo;
  final LyfiDeviceInfo ledInfo;
  final LyfiDeviceStatus ledStatus;

  SettingsViewModel({
    required this.address,
    required this.borneoStatus,
    required this.borneoInfo,
    required this.ledInfo,
    required this.ledStatus,
  });

}