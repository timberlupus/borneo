import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';

import '../../../shared/view_models/base_view_model.dart';

class GroupViewModel extends BaseViewModel with ViewModelEventBusMixin {
  List<AbstractDeviceSummaryViewModel> _devices = [];
  final IClock clock;
  late int _lastModified;

  String get id => model.id;
  String get name => model.name;
  List<AbstractDeviceSummaryViewModel> get devices => _devices;
  bool get isDummy => model.isDummy;
  int get lastModified => _lastModified;

  DeviceGroupEntity model;

  bool get isEmpty => _devices.isEmpty;

  GroupViewModel(this.model, {required this.clock, required super.gt}) {
    _lastModified = this.clock.now().millisecondsSinceEpoch;
  }

  void _updateModified() {
    _lastModified = this.clock.now().millisecondsSinceEpoch;
  }

  void addOrUpdateDevice(AbstractDeviceSummaryViewModel device) {
    final existingIndex = _devices.indexWhere((d) => d.deviceEntity.id == device.deviceEntity.id);
    if (existingIndex == -1) {
      // New device VM: take ownership and manage its lifecycle.
      _devices = [..._devices, device];
    } else {
      // Existing VM present -> perform in-place update to preserve identity.
      final existing = _devices[existingIndex];

      // Merge state from the incoming (temporary) VM into the existing VM.
      // Subclasses can override `updateFrom` to merge ValueNotifier state etc.
      existing.updateFrom(device);

      // The passed-in `device` was only a carrier/temporary instance created by
      // the factory; dispose it immediately since `existing` remains authoritative.
      if (!device.isDisposed) {
        device.dispose();
      }
    }
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
    if (!isDisposed) notifyListeners();
  }

  @override
  void dispose() {
    if (!isDisposed) {
      clearDevices();
      super.dispose();
    }
  }
}
