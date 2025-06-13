import 'dart:collection';
import 'package:logger/logger.dart';

import 'package:borneo_app/core/services/devices/device_module_harvesters.dart';
import 'package:borneo_app/features/devices/models/device_module_metadata.dart';

abstract class IDeviceModuleRegistry {
  UnmodifiableMapView<String, DeviceModuleMetadata> get metaModules;
}

class DeviceModuleRegistry implements IDeviceModuleRegistry {
  final Logger? logger;
  late final UnmodifiableMapView<String, DeviceModuleMetadata> _metaModules;

  @override
  UnmodifiableMapView<String, DeviceModuleMetadata> get metaModules => _metaModules;

  DeviceModuleRegistry(IDeviceModuleHarvester harvester, {this.logger}) {
    logger?.i('Loading device modules...');
    final modules = <String, DeviceModuleMetadata>{};
    for (final meta in harvester.harvest()) {
      logger?.i('Found device module: (id=`${meta.id}`, name=`${meta.name}`})');
      modules[meta.id] = meta;
    }
    _metaModules = UnmodifiableMapView(modules);
  }
}
