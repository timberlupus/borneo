import 'package:borneo_app/devices/view_models/abstract_device_summary_view_model.dart';
import 'package:borneo_app/models/devices/device_group_entity.dart';

import '/view_models/base_view_model.dart';

class GroupViewModel extends BaseViewModel {
  final List<AbstractDeviceSummaryViewModel> _devices = [];

  String get id => _model.id;
  String get name => _model.name;
  List<AbstractDeviceSummaryViewModel> get devices => _devices;
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

  @override
  void notifyAppError(String message, {Object? error, StackTrace? stackTrace}) {
    // TODO
  }
}
