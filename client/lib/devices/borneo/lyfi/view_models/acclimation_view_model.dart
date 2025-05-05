import 'package:borneo_app/view_models/base_view_model.dart';
import 'package:borneo_app/view_models/devices/base_device_view_model.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:flutter/material.dart';

class AcclimationViewModel extends BaseDeviceViewModel {
  int _days = 5;
  int get days => _days;

  bool _enabled = false;
  bool get enabled => _enabled;

  Future<void> setEanbled(bool value) async {
    _enabled = value;
    notifyListeners();
  }

  AcclimationViewModel(super.deviceID, super.deviceManager, {required super.globalEventBus});

  void updateDays(int newValue) {
    _days = newValue;
    notifyListeners();
  }

  @override
  Future<void> onInitialize() async {}

  @override
  Future<void> refreshStatus() async {}

  @override
  RssiLevel? get rssiLevel => null;
}
