import 'dart:core';

import 'package:borneo_common/borneo_common.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';
import '../../../packages/lw_wot/lib/wot.dart';

import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/ikernel.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';

abstract class DeviceManager implements IDisposable {
  final Logger? logger;

  DeviceManager({this.logger});

  // Abstract properties and methods
  bool get isInitialized;
  GlobalDevicesEventBus get allDeviceEvents;
  IKernel get kernel;
  Iterable<BoundDevice> get boundDevices;
  bool get isDiscoverying;

  // WotThing related properties
  Iterable<WotThing> get wotThingsInCurrentScene;
  Iterable<String> get deviceIDsWithWotThings;
  int get wotThingCount;

  // Abstract methods
  Future<void> initialize();
  bool isBound(String deviceID);
  BoundDevice getBoundDevice(String deviceID);
  Iterable<BoundDevice> getBoundDevicesInCurrentScene();
  Future<void> reloadAllDevices();
  Future<bool> tryBind(DeviceEntity device);
  Future<void> bind(DeviceEntity device);
  Future<void> unbind(String deviceID);
  Future<void> delete(String id, {Transaction? tx});
  Future<void> update(String id, {Transaction? tx, String? name, String? groupID});
  Future<void> moveToGroup(String id, String newGroupID);
  Future<bool> isNewDevice(SupportedDeviceDescriptor matched, {Transaction? tx});
  Future<DeviceEntity?> singleOrDefaultByFingerprint(String fingerprint, {Transaction? tx});
  Future<DeviceEntity> addNewDevice(SupportedDeviceDescriptor discovered, {String? groupID, Transaction? tx});
  Future<DeviceEntity> getDevice(String id, {Transaction? tx});
  Future<List<DeviceEntity>> fetchAllDevicesInScene({String? sceneID});
  Future<void> startDiscovery({Duration? timeout, CancellationToken? cancelToken});
  Future<void> stopDiscovery();

  // WotThing methods
  WotThing? getWotThing(String deviceID);
  Future<WotThing?> getOrCreateWotThing(String deviceID);
  bool hasWotThing(String deviceID);
}
