import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';

import '../../../shared/view_models/base_view_model.dart';

class GroupViewModel extends BaseViewModel {
  List<AbstractDeviceSummaryViewModel> _devices = [];
  int _lastModified = DateTime.now().millisecondsSinceEpoch;

  String get id => model.id;
  String get name => model.name;
  List<AbstractDeviceSummaryViewModel> get devices => _devices;
  bool get isDummy => model.isDummy;
  int get lastModified => _lastModified;

  DeviceGroupEntity model;

  bool get isEmpty => _devices.isEmpty;

  void _updateModified() {
    _lastModified = DateTime.now().millisecondsSinceEpoch;
  }

  void addDevice(AbstractDeviceSummaryViewModel device) {
    _devices = [..._devices, device];
    _updateModified();
    notifyListeners();
  }

  void insertDevice(int index, AbstractDeviceSummaryViewModel device) {
    _devices = [..._devices];
    _devices.insert(index, device);
    _updateModified();
    notifyListeners();
  }

  void removeDevice(AbstractDeviceSummaryViewModel device) {
    _devices = _devices.where((d) => d != device).toList();
    _updateModified();
    notifyListeners();
  }

  void removeDeviceById(String deviceId) {
    final originalLength = _devices.length;
    _devices = _devices.where((d) => d.deviceEntity.id != deviceId).toList();
    if (originalLength != _devices.length) {
      _updateModified();
      notifyListeners();
    }
  }

  void clearDevices() {
    for (final device in _devices) {
      if (!device.isDisposed) {
        device.dispose();
      }
    }
    _devices = [];
    _updateModified();
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
