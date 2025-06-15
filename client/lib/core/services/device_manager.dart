import 'dart:async';
import 'dart:core';

import 'package:borneo_common/borneo_common.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';
import 'package:synchronized/synchronized.dart';

import 'package:borneo_app/shared/models/base_entity.dart';
import 'package:borneo_app/features/devices/models/events.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_kernel_abstractions/models/supported_device_descriptor.dart';

import 'package:borneo_app/core/services/store_names.dart';
import 'package:borneo_kernel_abstractions/events.dart';
import 'package:borneo_kernel_abstractions/ikernel.dart';
import 'package:borneo_kernel_abstractions/models/bound_device.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';

final class DeviceManager implements IDisposable {
  bool _isDisposed = false;
  final Logger? logger;
  final Database _db;
  bool _isInitialized = false;
  final SceneManager _sceneManager;

  final Lock _deviceOperLock = Lock();

  // ignore: unused_field
  final EventBus _globalBus;
  // ignore: unused_field
  final GroupManager _groupManager;

  // event subscriptions
  late final StreamSubscription<UnboundDeviceDiscoveredEvent> _unboundDeviceDiscoveredEventSub;

  bool get isInitialized => _isInitialized;
  GlobalDevicesEventBus get allDeviceEvents => _kernel.events;

  final IKernel _kernel;
  IKernel get kernel => _kernel;

  Iterable<BoundDevice> get boundDevices => _kernel.boundDevices;

  DeviceManager(this._db, this._kernel, this._globalBus, this._sceneManager, this._groupManager, {this.logger}) {
    logger?.i("Creating DeviceManager...");
    _unboundDeviceDiscoveredEventSub = allDeviceEvents.on<UnboundDeviceDiscoveredEvent>().listen(
      _onUnboundDeviceDiscovered,
    );
  }

  Future<void> initialize() async {
    assert(!_isInitialized);

    logger?.i('Initializing DeviceManager...');
    try {
      final devices = await fetchAllDevicesInScene();
      _kernel.registerDevices(devices.map((x) => BoundDeviceDescriptor(device: x, driverID: x.driverID)));
      await _kernel.start();

      await _rebindAll(devices);
      /*
      await db.transaction((tx) async {
      });
      */
      logger?.i('DeviceManager has been initialized successfully.');
    } finally {
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    if (_isDisposed) {
      _unboundDeviceDiscoveredEventSub.cancel();
      _isDisposed = true;
    }
  }

  bool isBound(String deviceID) => _kernel.isBound(deviceID);

  BoundDevice getBoundDevice(String deviceID) => _kernel.getBoundDevice(deviceID);

  Iterable<BoundDevice> getBoundDevicesInCurrentScene() {
    final currentScene = _sceneManager.current;
    return _kernel.boundDevices.where((x) => (x.device as DeviceEntity).sceneID == currentScene.id);
  }

  Future<void> reloadAllDevices() async {
    await _deviceOperLock.synchronized(() async {
      await _kernel.unbindAll();
      _kernel.unregisterAllDevices();
      final devices = await fetchAllDevicesInScene();
      _kernel.registerDevices(devices.map((x) => BoundDeviceDescriptor(device: x, driverID: x.driverID)));
      await _rebindAll(devices);
    });
  }

  Future<void> _rebindAll(Iterable<DeviceEntity> devices) async {
    await _deviceOperLock.synchronized(() async {
      await _kernel.unbindAll();
      final futures = <Future>[];
      for (var device in devices) {
        futures.add(tryBind(device));
      }
      await Future.wait(futures);
    });
  }

  Future<bool> tryBind(DeviceEntity device) async => _kernel.tryBind(device, device.driverID);

  Future<void> bind(DeviceEntity device) => _kernel.bind(device, device.driverID);

  Future<void> unbind(String deviceID) => _kernel.unbind(deviceID);

  Future<void> delete(String id, {Transaction? tx}) async {
    if (tx == null) {
      await _db.transaction((tx) => delete(id, tx: tx));
    } else {
      if (_kernel.isBound(id)) {
        await _kernel.unbind(id);
      }
      _kernel.unregisterDevice(id);
      final store = stringMapStoreFactory.store(StoreNames.devices);
      await store.record(id).delete(tx);
      allDeviceEvents.fire(DeviceEntityDeletedEvent(id));
    }
  }

  Future<void> update(String id, {Transaction? tx, String? name, String? groupID}) async {
    if (tx == null) {
      return await _db.transaction((tx) => _update(id, tx: tx, name: name, groupID: groupID));
    } else {
      await _update(id, tx: tx, name: name, groupID: groupID);
    }
  }

  Future<void> _update(String id, {required Transaction tx, String? name, String? groupID}) async {
    final store = stringMapStoreFactory.store(StoreNames.devices);
    final originalRecord = await store.record(id).get(tx);
    if (originalRecord == null) {
      throw KeyNotFoundException(message: 'Cannot found device with ID `$id`');
    }
    final oldEntity = DeviceEntity.fromMap(id, originalRecord);
    final fieldsToUpdate = {
      DeviceEntity.kNameFieldName: originalRecord[DeviceEntity.kNameFieldName] ?? name,
      DeviceEntity.kGroupIDFieldName: originalRecord[DeviceEntity.kGroupIDFieldName] ?? groupID,
    };
    final updatedRecord = await store.record(id).update(tx, fieldsToUpdate);
    final updatedEntity = DeviceEntity.fromMap(id, updatedRecord!);
    allDeviceEvents.fire(DeviceEntityUpdatedEvent(oldEntity, updatedEntity));
  }

  Future<bool> _groupExists(Transaction tx, String groupID) async {
    final groupStore = stringMapStoreFactory.store(StoreNames.groups);
    final groupRecord = await groupStore.record(groupID).get(tx);
    return groupRecord != null;
  }

  Future<void> moveToGroup(String id, String newGroupID) async {
    return await _db.transaction((tx) async {
      final exists = await _groupExists(tx, newGroupID);
      if (!exists) {
        throw KeyNotFoundException(message: 'Cannot find group with ID `$newGroupID`');
      }
      return await _update(id, tx: tx, groupID: newGroupID);
    });
  }

  Future<bool> isNewDevice(SupportedDeviceDescriptor matched, {Transaction? tx}) async {
    if (tx == null) {
      return await _db.transaction((tx) => isNewDevice(matched, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.devices);
      final filter = Filter.equals(DeviceEntity.kFngerprintFieldName, matched.fingerprint);
      final n = await store.count(tx, filter: filter);
      return n == 0;
    }
  }

  Future<DeviceEntity?> singleOrDefaultByFingerprint(String fingerprint, {Transaction? tx}) async {
    if (tx == null) {
      return await _db.transaction((tx) => singleOrDefaultByFingerprint(fingerprint, tx: tx));
    } else {
      final store = stringMapStoreFactory.store(StoreNames.devices);
      final record = await store.findFirst(
        tx,
        finder: Finder(filter: Filter.equals(DeviceEntity.kFngerprintFieldName, fingerprint)),
      );
      if (record == null) {
        return null;
      }
      final device = DeviceEntity.fromMap(record.key, record.value);
      return device;
    }
  }

  Future<DeviceEntity> addNewDevice(SupportedDeviceDescriptor discovered, {String? groupID, Transaction? tx}) async {
    assert(isInitialized);

    final device = tx == null
        ? await _db.transaction((tx) async => await _addNewDeviceToStore(discovered, groupID: groupID, tx: tx))
        : await _addNewDeviceToStore(discovered, tx: tx);

    _kernel.registerDevice(BoundDeviceDescriptor(device: device, driverID: device.driverID));
    final bindResult = await tryBind(device);
    if (!bindResult) {
      logger?.e('Failed to bind device: $device');
    }
    return device;
  }

  Future<DeviceEntity> _addNewDeviceToStore(
    SupportedDeviceDescriptor discovered, {
    String? groupID,
    required Transaction tx,
  }) async {
    assert(isInitialized);
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
    allDeviceEvents.fire(NewDeviceEntityAddedEvent(device));
    return device;
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
      final finder = Finder(filter: Filter.equals(DeviceEntity.kSceneIDFieldName, sceneID ?? _sceneManager.current.id));
      final records = await store.find(tx, finder: finder);
      final devices = records.map((record) => DeviceEntity.fromMap(record.key, record.value)).toList();
      return devices;
    });
  }

  bool get isDiscoverying => _kernel.isScanning;

  Future<void> startDiscovery({Duration? timeout, CancellationToken? cancelToken}) async {
    assert(!_kernel.isScanning);
    await _kernel.startDevicesScanning(timeout: timeout, cancelToken: cancelToken);
  }

  Future<void> stopDiscovery() async {
    assert(_kernel.isScanning);
    await _kernel.stopDevicesScanning();
  }

  Future<void> _onUnboundDeviceDiscovered(UnboundDeviceDiscoveredEvent event) async {
    logger?.i('Device discovered: ${event.matched}');
    assert(isInitialized);
    return await _db.transaction((tx) async {
      final existed = await singleOrDefaultByFingerprint(event.matched.fingerprint, tx: tx);
      if (existed != null) {
        if (event.matched.address != existed.address) {
          // Otherwise we should update the `address` field
          final store = stringMapStoreFactory.store(StoreNames.devices);
          final record = store.record(existed.id);
          await record.update(tx, {DeviceEntity.kAddressFieldName: event.matched.address.toString()});
        }
      } else {
        allDeviceEvents.fire(NewDeviceFoundEvent(event.matched));
      }
    });
  }
}
