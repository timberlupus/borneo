import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/models/devices/device_group_entity.dart';

import '/view_models/base_view_model.dart';

class GroupViewModel extends BaseViewModel {
  List<AbstractDeviceSummaryViewModel> _devices = [];

  String get id => model.id;
  String get name => model.name;
  List<AbstractDeviceSummaryViewModel> get devices => _devices;
  bool get isDummy => model.isDummy;

  DeviceGroupEntity model;

  bool get isEmpty => _devices.isEmpty;

  void addDevice(AbstractDeviceSummaryViewModel device) {
    _devices = [..._devices, device];
    notifyListeners();
  }

  void insertDevice(int index, AbstractDeviceSummaryViewModel device) {
    _devices = [..._devices];
    _devices.insert(index, device);
    notifyListeners();
  }

  void removeDevice(AbstractDeviceSummaryViewModel device) {
    _devices = _devices.where((d) => d != device).toList();
    notifyListeners();
  }

  void removeDeviceById(String deviceId) {
    _devices = _devices.where((d) => d.deviceEntity.id != deviceId).toList();
    notifyListeners();
  }

  void clearDevices() {
    for (final device in _devices) {
      if (!device.isDisposed) {
        device.dispose();
      }
    }
    _devices = [];
    notifyListeners();
  }

  GroupViewModel(this.model);
  @override
  void dispose() {
    if (!isDisposed) {
      clearDevices();
      super.dispose();
    }
  }

  @override
  void notifyAppError(String message, {Object? error, StackTrace? stackTrace}) {
    // TODO
  }
}
