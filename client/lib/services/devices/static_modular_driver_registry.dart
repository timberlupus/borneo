import 'dart:collection';

import 'package:borneo_app/services/devices/device_module_registry.dart';
import 'package:borneo_kernel_abstractions/idriver_registry.dart';
import 'package:borneo_kernel_abstractions/models/driver_descriptor.dart';

class StaticModularDriverRegistry implements IDriverRegistry {
  final UnmodifiableMapView<String, DriverDescriptor> _metaDrivers;

  @override
  UnmodifiableMapView<String, DriverDescriptor> get metaDrivers => _metaDrivers;

  StaticModularDriverRegistry(IDeviceModuleRegistry staticModules)
    : _metaDrivers = UnmodifiableMapView(staticModules.metaModules.map((k, v) => MapEntry(k, v.driverDescriptor)));
}
