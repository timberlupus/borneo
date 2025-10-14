import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/driver.dart';
import 'package:cancellation_token/cancellation_token.dart';

import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_kernel_abstractions/device.dart';

import 'models/bound_device.dart';

export 'driver.dart';
export 'driver_registry.dart';
export 'errors.dart';
export 'events.dart';
export 'device.dart';
export 'command_queue.dart';
export 'mdns.dart';

export 'models/bound_device.dart';
export 'models/discovered_device.dart';
export 'models/driver_data.dart';
export 'models/driver_descriptor.dart';
export 'models/heartbeat_method.dart';
export 'models/supported_device_descriptor.dart';

abstract class IKernel implements IDisposable {
  Iterable<BoundDevice> get boundDevices;
  bool get isInitialized;
  GlobalDevicesEventBus get events;
  Iterable<IDriver> get activatedDrivers;
  bool get isBusy;
  bool get isScanning;

  Future<void> start();

  bool isBound(String deviceID);

  BoundDevice getBoundDevice(String deviceID);

  Future<bool> tryBind(Device device, String driverID, {CancellationToken? cancelToken});

  Future<void> bind(Device device, String driverID, {CancellationToken? cancelToken});

  Future<void> unbind(String deviceID, {CancellationToken? cancelToken});
  Future<void> unbindAll({CancellationToken? cancelToken});

  Future<void> startDevicesScanning({Duration? timeout, CancellationToken? cancelToken});
  Future<void> stopDevicesScanning();

  void registerDevice(BoundDeviceDescriptor device);
  void registerDevices(Iterable<BoundDeviceDescriptor> devices);
  void unregisterDevice(String deviceID);
  void unregisterAllDevices();
}
