import 'package:borneo_kernel_abstractions/models/driver_data.dart';

abstract class Device {
  final String id;
  final Uri address;
  final String fingerprint;

  Device({required this.id, required this.fingerprint, required this.address});

  DriverData get driverData;

  T data<T extends DriverData>() => driverData as T;

  void setDriverData(DriverData driverData);
}
