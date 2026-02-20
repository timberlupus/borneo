import 'dart:collection';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';

import 'package:borneo_app/features/devices/view_models/device_discovery_view_model.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/devices/ble_provisioner.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/features/devices/models/device_module_metadata.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:lw_wot/wot.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:flutter_esp_ble_prov/flutter_esp_ble_prov.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';

// Minimal implementations / fakes for the interfaces used by the view model.

class FakeGroupManager implements IGroupManager {
  @override
  bool get isInitialized => true;

  @override
  Future<void> create({required String name, String notes = '', Transaction? tx}) async {}

  @override
  Future<void> delete(String id, {Transaction? tx}) async {}

  @override
  Future<DeviceGroupEntity> fetch(String id, {Transaction? tx}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<DeviceGroupEntity>> fetchAllGroupsInCurrentScene({Transaction? tx}) async {
    return [];
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> update(String id, {required String name, String notes = '', Transaction? tx}) async {}
}

class FakeDeviceManager implements IDeviceManager {
  // ignore: unused_field
  final EventBus _bus = EventBus();

  @override
  bool get isDiscoverying => false;

  @override
  GlobalDevicesEventBus get allDeviceEvents => GlobalDevicesEventBus();

  @override
  Iterable<BoundDevice> get boundDevices => const [];

  @override
  Iterable<WotThing> get wotThingsInCurrentScene => const [];

  @override
  Iterable<String> get deviceIDsWithWotThings => const [];

  @override
  int get wotThingCount => 0;

  @override
  Future<void> initialize({CancellationToken? cancelToken}) async {}

  @override
  bool isBound(String deviceID) => false;

  @override
  BoundDevice getBoundDevice(String deviceID) {
    throw UnimplementedError();
  }

  @override
  Iterable<BoundDevice> getBoundDevicesInCurrentScene() => const [];

  @override
  Future<void> reloadAllDevices({CancellationToken? cancelToken}) async {}

  @override
  Future<bool> tryBind(DeviceEntity device) async => false;

  @override
  Future<void> bind(DeviceEntity device) async {}

  @override
  Future<void> unbind(String deviceID) async {}

  @override
  Future<void> delete(String id, {Transaction? tx}) async {}

  @override
  Future<void> update(String id, {Transaction? tx, String? name, String? groupID}) async {}

  @override
  Future<void> moveToGroup(String id, String newGroupID) async {}

  @override
  Future<bool> isNewDevice(SupportedDeviceDescriptor matched, {Transaction? tx}) async => false;

  @override
  Future<DeviceEntity?> singleOrDefaultByFingerprint(String fingerprint, {Transaction? tx}) async => null;

  @override
  Future<DeviceEntity> addNewDevice(SupportedDeviceDescriptor discovered, {String? groupID, Transaction? tx}) async {
    throw UnimplementedError();
  }

  @override
  Future<DeviceEntity> getDevice(String id, {Transaction? tx}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<DeviceEntity>> fetchAllDevicesInScene({String? sceneID}) async => [];

  @override
  Future<void> startDiscovery({Duration? timeout, CancellationToken? cancelToken}) async {}

  @override
  Future<void> stopDiscovery() async {}

  @override
  WotThing getWotThing(String deviceID) {
    throw UnimplementedError();
  }

  @override
  bool hasWotThing(String deviceID) => false;

  // IDisposable implementation
  @override
  bool get isInitialized => true;

  @override
  IKernel get kernel => throw UnimplementedError();

  @override
  void dispose() {}
}

class FakeBleProvisioner implements IBleProvisioner {
  bool scanCalled = false;
  Future<List<String>> Function(String prefix, {CancellationToken? cancelToken})? scanImpl;

  @override
  Future<List<String>> scanBleDevices(String prefix, {CancellationToken? cancelToken}) async {
    scanCalled = true;
    if (scanImpl != null) {
      return await scanImpl!(prefix, cancelToken: cancelToken);
    }
    return [];
  }

  @override
  Future<List<WifiNetwork>> scanWifiNetworks(
    String deviceName, {
    String pop = '',
    CancellationToken? cancelToken,
  }) async {
    throw UnimplementedError();
  }

  @override
  Future<void> provisionWifi(String deviceName, String ssid, String password, {CancellationToken? cancelToken}) async {
    throw UnimplementedError();
  }
}

class FakeDeviceModuleRegistry extends IDeviceModuleRegistry {
  @override
  UnmodifiableMapView<String, DeviceModuleMetadata> get metaModules => UnmodifiableMapView({});
}

class FakeGettextLocalizations implements GettextLocalizations {
  @override
  String translate(
    String key, {
    String? domain,
    String? keyPlural,
    String msgctxt = '',
    Map<String, Object>? nArgs,
    List<Object>? pArgs,
  }) => key;
}

void main() {
  group('DeviceDiscoveryViewModel permissions', () {
    late DeviceDiscoveryViewModel vm;
    late FakeBleProvisioner bleProv;

    setUp(() {
      bleProv = FakeBleProvisioner();
      vm = DeviceDiscoveryViewModel(
        Logger(),
        FakeGroupManager(),
        FakeDeviceManager(),
        bleProv,
        FakeDeviceModuleRegistry(),
        globalEventBus: EventBus(),
        gt: FakeGettextLocalizations(),
        logger: Logger(),
        requestBlePermissions: () async => false,
      );
    });

    test('startDiscovery does not call BLE scan when permissions denied', () async {
      expect(bleProv.scanCalled, isFalse);
      await vm.startDiscovery();
      expect(bleProv.scanCalled, isFalse);
      expect(vm.scanError.value, 'Bluetooth permissions are required to discover devices.');
    });

    test('startDiscovery calls BLE scan when permissions granted', () async {
      // create new vm with permission true
      vm = DeviceDiscoveryViewModel(
        Logger(),
        FakeGroupManager(),
        FakeDeviceManager(),
        bleProv,
        FakeDeviceModuleRegistry(),
        globalEventBus: EventBus(),
        gt: FakeGettextLocalizations(),
        logger: Logger(),
        requestBlePermissions: () async => true,
      );

      await vm.startDiscovery();
      // allow _startBleScan unawaited future to run
      await Future.delayed(Duration.zero);
      expect(bleProv.scanCalled, isTrue);
    });

    test('startDiscovery handles platform exception permission denial', () async {
      final errorProv = FakeBleProvisioner();
      // override to throw
      errorProv.scanImpl = (String prefix, {CancellationToken? cancelToken}) async {
        throw PlatformException(code: 'PERMISSION_DENIED', message: 'nope');
      };
      vm = DeviceDiscoveryViewModel(
        Logger(),
        FakeGroupManager(),
        FakeDeviceManager(),
        errorProv,
        FakeDeviceModuleRegistry(),
        globalEventBus: EventBus(),
        gt: FakeGettextLocalizations(),
        logger: Logger(),
        requestBlePermissions: () async => true,
      );

      await vm.startDiscovery();
      await Future.delayed(Duration.zero);
      expect(vm.scanError.value, 'Bluetooth permissions are required to discover devices.');
    });
  });
}
