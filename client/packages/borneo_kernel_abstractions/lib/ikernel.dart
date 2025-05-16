import 'package:borneo_kernel_abstractions/idriver.dart';
import 'package:cancellation_token/cancellation_token.dart';
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

  Future<bool> tryBind(
    Device device,
    String driverID, {
    Duration? timeout,
    CancellationToken? cancelToken,
  });

  Future<void> bind(Device device, String driverID,
      {Duration? timeout, CancellationToken? cancelToken});

  Future<void> unbind(String deviceID, {CancellationToken? cancelToken});
  Future<void> unbindAll({CancellationToken? cancelToken});

  bool get isScanning;

  Future<void> startDevicesScanning(
      {Duration? timeout, CancellationToken? cancelToken});
  Future<void> stopDevicesScanning();

  void registerDevice(BoundDeviceDescriptor device);
  void registerDevices(Iterable<BoundDeviceDescriptor> devices);
  void unregisterDevice(String deviceID);
  void unregisterAllDevices();
}
