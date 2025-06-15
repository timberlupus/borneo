import 'dart:async';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel_abstractions/models/driver_data.dart';

abstract class BorneoCoapDriverData extends DriverData {
  bool _disposed = false;
  final BorneoCoapClient probeCoap;
  final BorneoCoapClient coap;
  final GeneralBorneoDeviceInfo _generalDeviceInfo;
  StreamSubscription<bool>? _coapPowerOnOffSub;

  bool get isDisposed => _disposed;

  BorneoCoapDriverData(super.device, this.coap, this.probeCoap, this._generalDeviceInfo);

  void load() {
    _coapPowerOnOffSub = coap
        .observeCborNon<bool>(BorneoPaths.power)
        .listen((onOff) => super.deviceEvents.fire(DevicePowerOnOffChangedEvent(device, onOff)));
  }

  GeneralBorneoDeviceInfo get generalDeviceInfo {
    if (_disposed) {
      ObjectDisposedException(message: 'The object has been disposed.');
    }
    return _generalDeviceInfo;
  }

  @override
  void dispose() {
    if (!_disposed) {
      _coapPowerOnOffSub?.cancel();

      probeCoap.close();
      coap.close();

      super.dispose();

      _disposed = true;
    }
  }
}
