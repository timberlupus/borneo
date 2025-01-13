import 'dart:collection';

import 'models/driver_descriptor.dart';

abstract class IDriverRegistry {
  UnmodifiableMapView<String, DriverDescriptor> get metaDrivers;
}
