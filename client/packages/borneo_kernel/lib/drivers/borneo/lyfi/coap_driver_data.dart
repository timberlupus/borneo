import 'dart:async';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_common/io/net/coap_client.dart';
import 'package:borneo_kernel/drivers/borneo/coap_driver_data.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/events.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/coap_driver.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

class LyfiCoapDriverData extends BorneoCoapDriverData {
  LyfiDeviceInfo _lyfiDeviceInfo;
  bool _disposed = false;

  StreamSubscription? _modeChangedSub;
  StreamSubscription? _stateChangedSub;

  LyfiCoapDriverData(super.device, super.coap, super.probeCoap, super._generalDeviceInfo, this._lyfiDeviceInfo);

  @override
  void load() {
    super.load();

    _modeChangedSub = coap
        .observeCbor<int>(LyfiPaths.mode)
        .listen((mode) => super.deviceEvents.fire(LyfiModeChangedEvent(device, mode: LyfiMode.values[mode])));

    _stateChangedSub = coap
        .observeCbor<int>(LyfiPaths.state)
        .listen((state) => super.deviceEvents.fire(LyfiStateChangedEvent(device, state: LyfiState.values[state])));
  }

  LyfiDeviceInfo get lyfiDeviceInfo {
    if (super.isDisposed) {
      ObjectDisposedException(message: 'The object has been disposed.');
    }
    return _lyfiDeviceInfo;
  }

  set lyfiDeviceInfo(LyfiDeviceInfo info) {
    if (super.isDisposed) {
      ObjectDisposedException(message: 'The object has been disposed.');
    }
    _lyfiDeviceInfo = info;
  }

  @override
  void dispose() {
    if (!_disposed) {
      _modeChangedSub?.cancel();
      _stateChangedSub?.cancel();

      super.dispose();
      _disposed = true;
    }
  }
}
