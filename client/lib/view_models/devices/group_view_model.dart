import 'package:borneo_app/models/devices/device_group_entity.dart';
import 'package:borneo_app/view_models/devices/device_summary_view_model.dart';

import '/view_models/base_view_model.dart';

class GroupViewModel extends BaseViewModel {
  final List<DeviceSummaryViewModel> _devices = [];

  String get id => _model.id;
  String get name => _model.name;
  List<DeviceSummaryViewModel> get devices => _devices;
  bool get isDummy => _model.isDummy;

  DeviceGroupEntity _model;
  DeviceGroupEntity get model => _model;
  set model(groupEntity) => _model = groupEntity;

  bool get isEmpty => _devices.isEmpty;

  GroupViewModel(this._model);

  @override
  void dispose() {
    if (!isDisposed) {
      for (final device in _devices) {
        if (!device.isDisposed) {
          device.dispose();
        }
      }
      super.dispose();
    }
  }
}
