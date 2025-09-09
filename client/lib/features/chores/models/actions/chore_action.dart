import 'package:borneo_app/core/services/devices/device_manager.dart';

abstract class ChoreAction {
  static const String kDeviceID = "deviceID";
  final String deviceId;

  ChoreAction({required this.deviceId});
  Future<void> execute(IDeviceManager deviceManager);
  Future<void> undo(IDeviceManager deviceManager);
}
