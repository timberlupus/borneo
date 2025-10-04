import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';

class ControllerSettingsViewModel extends BaseLyfiDeviceViewModel {
  final GettextLocalizations _gt;

  ILyfiDeviceApi get api => deviceManager.getBoundDevice(deviceID).api<ILyfiDeviceApi>();

  int _pwmFreq = 500;
  int _initialPwmFreq = 500;
  int get pwmFreq => _pwmFreq;
  bool get pwmFreqChanged => _pwmFreq != _initialPwmFreq;
  void setPwmFreq(int? freq) {
    _pwmFreq = freq!;
    notifyListeners();
  }

  bool get hasChanges => pwmFreqChanged;

  ControllerSettingsViewModel(
    this._gt, {
    required super.deviceID,
    required super.deviceManager,
    required super.globalEventBus,
    required super.notification,
  });

  @override
  Future<void> onInitialize() async {
    await super.onInitialize();

    _pwmFreq = await this.borneoDeviceApi.getFactoryNvsU16(boundDevice!.device, "led", "pwmfreq");
    _initialPwmFreq = _pwmFreq;
  }

  Future<void> submit() async {
    if (pwmFreqChanged) {
      await this.borneoDeviceApi.setFactoryNvsU16(boundDevice!.device, "led", "pwmfreq", _pwmFreq);
      _initialPwmFreq = _pwmFreq;
    }

    this.borneoDeviceApi.reboot(boundDevice!.device);
  }
}
