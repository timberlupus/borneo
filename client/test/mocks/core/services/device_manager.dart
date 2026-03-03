import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'package:lw_wot/wot.dart';

/// Very small ``IDeviceManager`` stub used in multiple tests.  Most of the
/// callers only read a few simple properties or invoke ``fetchAllDevicesInScene``.
class StubDeviceManager implements IDeviceManager {
  final bool initialized;
  final Iterable<BoundDevice> bound;
  final Iterable<WotThing> things;
  final bool discoverying;

  final EventDispatcher _events = DefaultEventDispatcher();

  StubDeviceManager({
    this.initialized = true,
    this.bound = const [],
    this.things = const [],
    this.discoverying = false,
  });

  @override
  bool get isInitialized => initialized;

  @override
  Iterable<BoundDevice> get boundDevices => bound;

  @override
  Iterable<WotThing> get allWotThings => things;

  @override
  Iterable<WotThing> get wotThingsInCurrentScene => things;

  @override
  bool get isDiscoverying => discoverying;

  @override
  EventDispatcher get allDeviceEvents => _events;

  @override
  Future<List<DeviceEntity>> fetchAllDevicesInScene({String? sceneID}) async => [];

  // a few very-common helpers used by view models
  @override
  bool isBound(String deviceID) => false;

  @override
  bool hasWotThing(String deviceID) => false;

  @override
  WotThing getWotThing(String deviceID) => throw UnimplementedError();

  // provide the minimal required members; most calls will simply hit noSuchMethod
  @override
  IKernel get kernel => throw UnimplementedError();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
