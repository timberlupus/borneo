import 'dart:async';

import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/events.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:event_bus/event_bus.dart';

abstract class BorneoCoapDriverData extends IDisposable {
  bool _disposed = false;
  final Device device;
  final EventBus deviceEventBus;
  final BorneoCoapClient probeCoap;
  final BorneoCoapClient coap;
  final GeneralBorneoDeviceInfo _generalDeviceInfo;
  StreamSubscription<bool>? _powerOnOffSub;

  bool get isDisposed => _disposed;

  BorneoCoapDriverData(this.device, this.coap, this.probeCoap,
      this._generalDeviceInfo, this.deviceEventBus);

  void load() {
    _powerOnOffSub = coap.observeCborNon<bool>(BorneoPaths.power).listen(
        (onOff) =>
            deviceEventBus.fire(DevicePowerOnOffChangedEvent(device, onOff)));
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
      _powerOnOffSub?.cancel();

      probeCoap.close();
      coap.close();
      _disposed = true;
    }
  }
}
