import 'package:borneo_kernel_abstractions/models/driver_descriptor.dart';

class SupportedDeviceDescriptor {
  final DriverDescriptor driverDescriptor;
  final String name;
  final Uri address;
  final String fingerprint;
  final String compatible;
  final String model;
  final String? manuf;
  final String? serno;

  const SupportedDeviceDescriptor({
    required this.driverDescriptor,
    required this.name,
    required this.address,
    required this.fingerprint,
    required this.compatible,
    required this.model,
    this.manuf,
    this.serno,
  });
}
