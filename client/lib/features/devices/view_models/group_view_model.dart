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
      _devices = [..._devices, device];
    } else {
      // Replace the existing VM in the list first so the UI can update and
      // detach any listeners from the old VM. Dispose the old VM later to
      // avoid `ValueNotifier`-after-dispose errors (widgets may still be
      // listening during the current frame).
      final oldDevice = _devices[existingIndex];
      _devices = [..._devices];
      _devices[existingIndex] = device;

      // Defer disposal to the next microtask/frame so widgets have a chance
      // to remove their listeners from the old ValueNotifiers first.
      Future.microtask(() {
        if (!oldDevice.isDisposed) {
          oldDevice.dispose();
        }
      });
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
    notifyListeners();
  }

  @override
  void dispose() {
    if (!isDisposed) {
      clearDevices();
      super.dispose();
    }
  }
}
