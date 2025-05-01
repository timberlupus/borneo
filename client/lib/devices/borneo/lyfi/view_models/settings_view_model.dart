import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';

class SettingsViewModel extends BaseViewModel {
  final Uri address;
  final GeneralBorneoDeviceStatus borneoStatus;
  final GeneralBorneoDeviceInfo borneoInfo;
  final LyfiDeviceInfo ledInfo;
  final LyfiDeviceStatus ledStatus;

  PowerBehavior _selectedPowerBehavior;
  PowerBehavior get selectedPowerBehavior => _selectedPowerBehavior;
  set selectedPowerBehavior(PowerBehavior value) {
    _selectedPowerBehavior = value;
    notifyListeners(); // 通知 UI 更新
  }

  SettingsViewModel({
    required this.address,
    required this.borneoStatus,
    required this.borneoInfo,
    required this.ledInfo,
    required this.ledStatus,
    required PowerBehavior powerBehavior,
  }) : _selectedPowerBehavior = powerBehavior;
}
