import 'package:borneo_kernel_abstractions/models/driver_data.dart';
import 'package:cancellation_token/cancellation_token.dart';

abstract class Device {
  final String id;
  final Uri address;
  final String fingerprint;

  Device({required this.id, required this.fingerprint, required this.address});

  dynamic get driverData;

  T data<T extends DriverData>() => driverData! as T;

  Future<void> setDriverData(dynamic driverData, {CancellationToken? cancelToken});
}
