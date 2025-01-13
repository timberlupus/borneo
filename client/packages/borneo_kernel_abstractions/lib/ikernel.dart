import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:event_bus/event_bus.dart';

import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_kernel_abstractions/device.dart';

import 'models/bound_device.dart';

abstract class IKernel implements IDisposable {
  Iterable<BoundDevice> get boundDevices;
  bool get isInitialized;
  EventBus get events;
  Iterable<IDriver> get activatedDrivers;

  Future<void> start();

  bool isBound(String deviceID);

  BoundDevice getBoundDevice(String deviceID);

  Future<bool> tryBind(Device device, String driverID);

  Future<void> bind(Device device, String driverID);

  Future<void> unbind(String deviceID);
  Future<void> unbindAll();

  bool get isScanning;

  Future<void> startDevicesScanning({Duration? timeout});
  Future<void> stopDevicesScanning();

  // DriverDescriptor? matchesDriver(DiscoveredDevice discovered);
}
