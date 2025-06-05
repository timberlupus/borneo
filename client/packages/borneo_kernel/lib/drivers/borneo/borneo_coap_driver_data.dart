import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:coap/coap.dart';
import 'package:event_bus/event_bus.dart';

abstract class BorneoCoapDriverData extends IDisposable {
  bool _disposed = false;
  final EventBus deviceEventBus;
  final BorneoCoapClient _probeCoap;
  final BorneoCoapClient _coap;
  final GeneralBorneoDeviceInfo _generalDeviceInfo;

  bool get isDisposed => _disposed;

  BorneoCoapDriverData(this._coap, this._probeCoap, this._generalDeviceInfo,
      this.deviceEventBus);

  CoapClient get coap {
    if (_disposed) {
      ObjectDisposedException(message: 'The object has been disposed.');
    }
    return _coap;
  }

  CoapClient get probeCoap {
    if (_disposed) {
      ObjectDisposedException(message: 'The object has been disposed.');
    }
    return _probeCoap;
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
      _probeCoap.close();
      _coap.close();
      _disposed = true;
    }
  }
}
