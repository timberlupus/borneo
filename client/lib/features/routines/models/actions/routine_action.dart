import 'package:borneo_app/core/services/devices/i_device_manager.dart';

abstract class RoutineAction {
  static const String kDeviceID = "deviceID";
  final String deviceId;

  RoutineAction({required this.deviceId});
  Future<void> execute(IDeviceManager deviceManager);
  Future<void> undo(IDeviceManager deviceManager);
}
