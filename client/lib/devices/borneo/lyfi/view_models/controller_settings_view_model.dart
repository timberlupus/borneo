import 'package:borneo_app/devices/borneo/lyfi/view_models/base_lyfi_device_view_model.dart';
import 'package:borneo_app/core/infrastructure/timezone.dart';
import 'package:borneo_common/exceptions.dart' as bo_ex;
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:geolocator/geolocator.dart';

import 'package:latlong2/latlong.dart';

class ControllerSettingsViewModel extends BaseLyfiDeviceViewModel {
  final GettextLocalizations _gt;

  ILyfiDeviceApi get api => deviceManager.getBoundDevice(deviceID).api<ILyfiDeviceApi>();

  int _pwmFreq = 500;
  int get pwmFreq => _pwmFreq;
  void setPwmFreq(int? freq) {
    // TODO 检查范围
    _pwmFreq = freq!;
  }

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
  }

  Future<void> submit() async {
    this.borneoDeviceApi.reboot(boundDevice!.device);
  }
}
