import 'dart:collection';

import 'package:borneo_app/features/devices/models/device_module_metadata.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';

/// Minimal implementation used by view‑model tests; the map can be supplied
/// via constructor if a test needs specific entries.
class StubDeviceModuleRegistry implements IDeviceModuleRegistry {
  final UnmodifiableMapView<String, DeviceModuleMetadata> _metaModules;

  StubDeviceModuleRegistry([Map<String, DeviceModuleMetadata>? modules])
    : _metaModules = UnmodifiableMapView(modules ?? {});

  @override
  UnmodifiableMapView<String, DeviceModuleMetadata> get metaModules => _metaModules;
}
