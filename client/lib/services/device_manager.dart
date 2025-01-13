import 'dart:async';
import 'dart:core';

import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel_abstractions/device_capability.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';

import 'package:borneo_app/models/base_entity.dart';
import 'package:borneo_app/models/devices/events.dart';
import 'package:borneo_app/services/group_manager.dart';
import 'package:borneo_app/services/scene_manager.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';

import 'package:borneo_app/services/store_names.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/ikernel.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_app/models/devices/device_entity.dart';

import '../models/devices/device_state.dart';

final class DeviceManager {
  final Logger _logger;
  final Database _db;
  bool _isInitialized = false;
  final SceneManager _sceneManager;

  // ignore: unused_field
  final EventBus _globalBus;
  // ignore: unused_field
  final GroupManager _groupManager;

  // event subscriptions
  late final StreamSubscription<UnboundDeviceDiscoveredEvent>
      _unboundDeviceDiscoveredEventSub;

  bool get isInitialized => _isInitialized;
  EventBus get deviceEvents => _kernel.events;

  final IKernel _kernel;
  IKernel get kernel => _kernel;

  Iterable<BoundDevice> get boundDevices => _kernel.boundDevices;

  DeviceManager(this._logger, this._db, this._kernel, this._globalBus,
      this._sceneManager, this._groupManager) {
    _unboundDeviceDiscoveredEventSub = deviceEvents
        .on<UnboundDeviceDiscoveredEvent>()
        .listen(_onUnboundDeviceDiscovered);
  }

  Future<void> initialize() async {
    _logger.i('Initializing DeviceManager...');
    try {
      _kernel.start();
      await rebindAll();
      /*
      await db.transaction((tx) async {
      });
      */
      _logger.i('DeviceManager has been initialized successfully.');
    } finally {
      _isInitialized = true;
    }
  }

  void dispose() {
    _unboundDeviceDiscoveredEventSub.cancel();
    _kernel.dispose();
  }

  bool isBound(String deviceID) => _kernel.isBound(deviceID);

  BoundDevice getBoundDevice(String deviceID) =>
      _kernel.getBoundDevice(deviceID);

  Future<void> rebindAll() async {
    await _kernel.unbindAll();
    final devices = await fetchAllDevicesInScene();
    final futures = <Future>[];
    for (var device in devices) {
      futures.add(tryBind(device));
    }
    await Future.wait(futures);
  }

  Future<bool> tryBind(DeviceEntity device) async =>
      _kernel.tryBind(device, device.driverID);

  Future<void> bind(DeviceEntity device) =>
      _kernel.bind(device, device.driverID);

  Future<void> unbind(String deviceID) => _kernel.unbind(deviceID);

  Future<void> addDevice(Device device) async {}

  Future<void> delete(String id, {Transaction? tx}) async {
    if (tx == null) {
      await _db.transaction((tx) => delete(id, tx: tx));
    } else {
      if (_kernel.isBound(id)) {
        await _kernel.unbind(id);
      }
      final store = stringMapStoreFactory.store(StoreNames.devices);
      await store.record(id).delete(tx);
      deviceEvents.fire(DeviceEntityDeletedEvent(id));
    }
  }

  Future<void> update(String id,
      {Transaction? tx, String? name, String? groupID}) async {
    if (tx == null) {
      return await _db.transaction(
          (tx) => _update(id, tx: tx, name: name, groupID: groupID));
    } else {
      await _update(id, tx: tx, name: name, groupID: groupID);
    }
  }

  Future<void> _update(String id,
      {required Transaction tx, String? name, String? groupID}) async {
    final store = stringMapStoreFactory.store(StoreNames.devices);
    final originalRecord = await store.record(id).get(tx);
    if (originalRecord == null) {
      throw KeyNotFoundException('Cannot found device with ID `$id`');
    }
    final oldEntity = DeviceEntity.fromMap(id, originalRecord);
    final fieldsToUpdate = {
      DeviceEntity.kNameFieldName:
          originalRecord[DeviceEntity.kNameFieldName] ?? name,
      DeviceEntity.kGroupIDFieldName:
          originalRecord[DeviceEntity.kGroupIDFieldName] ?? groupID,
    };
    final updatedRecord = await store.record(id).update(tx, fieldsToUpdate);
    final updatedEntity = DeviceEntity.fromMap(id, updatedRecord!);
    deviceEvents.fire(DeviceEntityUpdatedEvent(oldEntity, updatedEntity));
  }

  Future<void> moveToGroup(String id, String newGroupID) async {
    return await _db.transaction((tx) async {
      // TODO ensure newGroupID exists
      return await _update(id, tx: tx, groupID: newGroupID);
    });
  }

  Future<bool> isNewDevice(SupportedDeviceDescriptor matched,
      {Transaction? tx}) async {
    if (tx == null) {
      return await _db.transaction((tx) => isNewDevice(matched, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.devices);
      final filter =
          Filter.equals(DeviceEntity.kFngerprintFieldName, matched.fingerprint);
      final n = await store.count(tx, filter: filter);
      return n == 0;
    }
  }

  Future<DeviceEntity?> singleOrDefaultByFingerprint(String fingerprint,
      {Transaction? tx}) async {
    if (tx == null) {
      return await _db.transaction(
          (tx) => singleOrDefaultByFingerprint(fingerprint, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.devices);
      final record = await store.findFirst(tx,
          finder: Finder(
              filter: Filter.equals(
                  DeviceEntity.kFngerprintFieldName, fingerprint)));
      if (record == null) {
        return null;
      }
      final device = DeviceEntity.fromMap(record.key, record.value);
      return device;
    }
  }

  Future<DeviceState> getDeviceState(String deviceID) async {
    if (isBound(deviceID)) {
      final bound = _kernel.getBoundDevice(deviceID);
      if (bound.driver is IReadOnlyPowerOnOffCapability) {
        // TODO adding lastValue to avoid async
        final isOn = await bound
            .api<IReadOnlyPowerOnOffCapability>()
            .getOnOff(bound.device);
        return isOn ? DeviceState.operational : DeviceState.powerOff;
      } else {
        return DeviceState.powerOff;
      }
    } else {
      return DeviceState.offline;
    }
  }

  Future<DeviceEntity> addNewDevice(SupportedDeviceDescriptor discovered,
      {String? groupID, Transaction? tx}) async {
    assert(isInitialized);
    if (tx == null) {
      return await _db.transaction((tx) async {
        return await addNewDevice(discovered, groupID: groupID, tx: tx);
      });
    } else {
      final store = stringMapStoreFactory.store(StoreNames.devices);

      final device = DeviceEntity(
        id: BaseEntity.generateID(),
        sceneID: _sceneManager.current.id,
        driverID: discovered.driverDescriptor.id,
        groupID: groupID,
        address: discovered.address,
        compatible: discovered.compatible,
        fingerprint: discovered.fingerprint,
        name: discovered.name,
        model: discovered.model,
      );
      await store.record(device.id).put(tx, device.toMap());
      final bindResult = await tryBind(device);
      if (!bindResult) {
        _logger.e('Failed to bind device: $device');
      }
      deviceEvents.fire(NewDeviceEntityAddedEvent(device));
      return device;
    }
  }

  Future<DeviceEntity> getDevice(String id, {Transaction? tx}) async {
    if (tx == null) {
      return await _db.transaction((tx) async {
        return await getDevice(id, tx: tx);
      });
    } else {
      final store = stringMapStoreFactory.store(StoreNames.devices);
      final record = await store.record(id).get(tx);
      final device = DeviceEntity.fromMap(id, record!);
      return device;
    }
  }

  Future<List<DeviceEntity>> fetchAllDevicesInScene({String? sceneID}) async {
    return await _db.transaction((tx) async {
      final store = stringMapStoreFactory.store(StoreNames.devices);
      final finder = Finder(
        filter: Filter.equals(DeviceEntity.kSceneIDFieldName,
            sceneID ?? _sceneManager.current.id),
      );
      final records = await store.find(tx, finder: finder);
      final devices = records
          .map((record) => DeviceEntity.fromMap(record.key, record.value))
          .toList();
      return devices;
    });
  }

  bool get isDiscoverying => _kernel.isScanning;

  Future<void> startDiscovery({Duration? timeout}) async {
    assert(!_kernel.isScanning);
    await _kernel.startDevicesScanning(timeout: timeout);
  }

  Future<void> stopDiscovery() async {
    assert(_kernel.isScanning);
    await _kernel.stopDevicesScanning();
  }

  Future<void> _onUnboundDeviceDiscovered(
      UnboundDeviceDiscoveredEvent event) async {
    _logger.i('Device discovered: ${event.matched}');
    assert(isInitialized);
    return await _db.transaction((tx) async {
      final existed =
          await singleOrDefaultByFingerprint(event.matched.fingerprint, tx: tx);
      if (existed != null) {
        if (event.matched.address != existed.address) {
          // Otherwise we should update the `address` field
          final store = stringMapStoreFactory.store(StoreNames.devices);
          final record = store.record(existed.id);
          await record.update(tx, {
            DeviceEntity.kAddressFieldName: event.matched.address.toString()
          });
        }
      } else {
        deviceEvents.fire(NewDeviceFoundEvent(event.matched));
      }
    });
  }
}
