import 'package:borneo_app/devices/all_devices.dart';

import '../../../features/devices/models/device_module_metadata.dart';

abstract class IDeviceModuleHarvester {
  Iterable<DeviceModuleMetadata> harvest();
}

class StaticDeviceModuleHarvester implements IDeviceModuleHarvester {
  @override
  Iterable<DeviceModuleMetadata> harvest() {
    return allDeviceModules;
  }
}
