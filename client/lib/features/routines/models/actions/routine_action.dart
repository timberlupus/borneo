import 'package:borneo_app/core/services/devices/device_manager.dart';

abstract class RoutineAction {
  static const String kDeviceID = "deviceID";
  final String deviceId;

  RoutineAction({required this.deviceId});
  Future<void> execute(DeviceManager deviceManager);
  Future<void> undo(DeviceManager deviceManager);
}
