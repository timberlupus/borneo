import 'dart:async';

import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel_abstractions/models/driver_data.dart';

abstract class BorneoCoapDriverData extends DriverData {
  bool _disposed = false;
  final BorneoCoapClient probeCoap;
  final BorneoCoapClient coap;
  StreamSubscription<bool>? _coapPowerOnOffSub;

  bool get isDisposed => _disposed;

  BorneoCoapDriverData(super.device, this.coap, this.probeCoap);

  void load() {
    _coapPowerOnOffSub = coap
        .observeCbor<bool>(BorneoPaths.power)
        .listen((onOff) => super.deviceEvents.fire(DevicePowerOnOffChangedEvent(device, onOff: onOff)));
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
