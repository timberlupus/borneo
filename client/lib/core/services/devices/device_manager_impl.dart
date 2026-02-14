import 'dart:async';
import 'dart:core';

import 'package:borneo_common/exceptions.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:sembast/sembast.dart';
import 'package:synchronized/synchronized.dart';
import 'package:lw_wot/wot.dart';

import 'package:borneo_app/features/devices/models/events.dart';
import 'package:borneo_app/core/models/events.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';

import 'package:borneo_app/core/services/store_names.dart';
import 'package:borneo_kernel_abstractions/kernel.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/shared/models/base_entity.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_common/io/net/network_interface_helper.dart';

final class DeviceManagerImpl extends IDeviceManager {
  final Logger? logger;
  bool _isDisposed = false;
  final Database _db;
  bool _isInitialized = false;
  final ISceneManager _sceneManager;

  final Lock _deviceOperLock = Lock();

  // ignore: unused_field
  final EventBus _globalBus;
  // ignore: unused_field
  final IGroupManager _groupManager;

  // event subscriptions
  late final StreamSubscription<UnboundDeviceDiscoveredEvent> _unboundDeviceDiscoveredEventSub;
  late final StreamSubscription<CurrentSceneChangedEvent> _currentSceneChangedEventSub;

  // WotThing management
  final Map<String, WotThing> _wotThings = {};
  final IDeviceModuleRegistry _deviceModuleRegistry;

  final IKernel _kernel;

  DeviceManagerImpl(
    this._db,
    this._kernel,
    this._globalBus,
    this._sceneManager,
    this._groupManager,
    this._deviceModuleRegistry, {
    this.logger,
  }) {
    logger?.i("Creating DeviceManagerImpl...");
    _unboundDeviceDiscoveredEventSub = allDeviceEvents.on<UnboundDeviceDiscoveredEvent>().listen(
      _onUnboundDeviceDiscovered,
    );

    // Listen for scene changes to manage WotThing lifecycle
    _currentSceneChangedEventSub = _globalBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged);
  }

  @override
  bool get isInitialized => _isInitialized;

  @override
  GlobalDevicesEventBus get allDeviceEvents => _kernel.events;

  @override
  IKernel get kernel => _kernel;

  @override
  Iterable<BoundDevice> get boundDevices => _kernel.boundDevices;

  @override
  Future<void> initialize() async {
    assert(!_isInitialized);

    logger?.i('Initializing DeviceManagerImpl...');
    try {
      final devices = await fetchAllDevicesInScene();
      _kernel.registerDevices(devices.map((x) => BoundDeviceDescriptor(device: x, driverID: x.driverID)));
      await _kernel.start();

      unawaited(() async {
        // Load WotThings for current scene alongside device load, regardless of online state.
        await _loadWotThingsForCurrentScene();
        await _rebindAll(devices);

        final currentScene = _sceneManager.current;
        _globalBus.fire(CurrentSceneDevicesReloadedEvent(currentScene));
        logger?.d('Fired CurrentSceneDevicesReloadedEvent for initial scene: ${currentScene.name}');
      }());

      logger?.i('DeviceManagerImpl has been initialized successfully.');
    } finally {
      _isInitialized = true;
    }
  }

  @override
  void dispose() {
    if (!_isDisposed) {
      _unboundDeviceDiscoveredEventSub.cancel();
      _currentSceneChangedEventSub.cancel();

      _disposeAllWotThings();

      _isDisposed = true;
    }
  }

  @override
  bool isBound(String deviceID) => _kernel.isBound(deviceID);

  @override
  BoundDevice getBoundDevice(String deviceID) => _kernel.getBoundDevice(deviceID);

  @override
  Iterable<BoundDevice> getBoundDevicesInCurrentScene() {
    final currentScene = _sceneManager.current;
    final devices = _kernel.boundDevices.where((x) => (x.device as DeviceEntity).sceneID == currentScene.id);
    return devices;
  }

  @override
  Future<void> reloadAllDevices() async {
    await _deviceOperLock.synchronized(() async {
      await _kernel.unbindAll();
      _kernel.unregisterAllDevices();
      final devices = await fetchAllDevicesInScene();
      _kernel.registerDevices(devices.map((x) => BoundDeviceDescriptor(device: x, driverID: x.driverID)));
      await _reloadWotThingsForCurrentScene();
      await _rebindAll(devices);
    });
  }

  Future<void> _rebindAll(Iterable<DeviceEntity> devices) async {
    await _kernel.unbindAll();
    final futures = <Future>[];
    for (var device in devices) {
      futures.add(tryBind(device));
    }
    await Future.wait(futures);
    _globalBus.fire(DeviceManagerReadyEvent());
  }

  @override
  Future<bool> tryBind(DeviceEntity device) async => _kernel.tryBind(device, device.driverID);

  @override
  Future<void> bind(DeviceEntity device) => _kernel.bind(device, device.driverID);

  @override
  Future<void> unbind(String deviceID) => _kernel.unbind(deviceID);

  @override
  Future<void> delete(String id, {Transaction? tx}) async {
    if (tx == null) {
      await _db.transaction((tx) => delete(id, tx: tx));
    } else {
      if (_kernel.isBound(id)) {
        await _kernel.unbind(id);
      }
      _kernel.unregisterDevice(id);
      _disposeWotThing(id);
      final store = stringMapStoreFactory.store(StoreNames.devices);
      await store.record(id).delete(tx);
      allDeviceEvents.fire(DeviceEntityDeletedEvent(id));
    }
  }

  @override
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
    final fieldsToUpdate = <String, dynamic>{};

    if (name != null) {
      fieldsToUpdate[DeviceEntity.kNameFieldName] = name;
    }
    if (groupID != null) {
      fieldsToUpdate[DeviceEntity.kGroupIDFieldName] = groupID;
    }

    final updatedRecord = await store.record(id).update(tx, fieldsToUpdate);
    final updatedEntity = DeviceEntity.fromMap(id, updatedRecord!);
    allDeviceEvents.fire(DeviceEntityUpdatedEvent(oldEntity, updatedEntity));
  }

  Future<bool> _groupExists(Transaction tx, String groupID) async {
    final groupStore = stringMapStoreFactory.store(StoreNames.groups);
    final groupRecord = await groupStore.record(groupID).get(tx);
    return groupRecord != null;
  }

  @override
  Future<void> moveToGroup(String id, String newGroupID) async {
    return await _db.transaction((tx) async {
      // Allow empty string for ungrouped devices
      if (newGroupID.isNotEmpty) {
        final exists = await _groupExists(tx, newGroupID);
        if (!exists) {
          throw KeyNotFoundException(message: 'Cannot find group with ID `$newGroupID`');
        }
      }
      return await _update(id, tx: tx, groupID: newGroupID);
    });
  }

  @override
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

  @override
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

  @override
  Future<DeviceEntity> addNewDevice(SupportedDeviceDescriptor discovered, {String? groupID, Transaction? tx}) async {
    assert(isInitialized);

    final device = tx == null
        ? await _db.transaction((tx) async => await _addNewDeviceToStore(discovered, groupID: groupID, tx: tx))
        : await _addNewDeviceToStore(discovered, tx: tx);

    _kernel.registerDevice(BoundDeviceDescriptor(device: device, driverID: device.driverID));

    // Always create a WotThing twin, even when the device is unbound/offline.
    await _loadWotThingForDevice(device, replaceExisting: true);

    final bindResult = await tryBind(device);
    if (!bindResult) {
      logger?.e('Failed to bind device: $device');
    }

    allDeviceEvents.fire(NewDeviceEntityAddedEvent(device));

    // Fire event to notify that devices in current scene have been reloaded
    final currentScene = _sceneManager.current;
    _globalBus.fire(CurrentSceneDevicesReloadedEvent(currentScene));
    logger?.d('Fired CurrentSceneDevicesReloadedEvent after adding device: ${device.name}');
    return device;
  }

  Future<DeviceEntity> _addNewDeviceToStore(
    SupportedDeviceDescriptor discovered, {
    String? groupID,
    required Transaction tx,
  }) async {
    assert(isInitialized);
    final store = stringMapStoreFactory.store(StoreNames.devices);

    final networkInterface = await NetworkInterfaceHelper.inferNetworkInterface(discovered.address.host);
    logger?.d('Inferred network interface for new device ${discovered.fingerprint}: $networkInterface');

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
    return device;
  }

  @override
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

  @override
  Future<List<DeviceEntity>> fetchAllDevicesInScene({String? sceneID}) async {
    return await _db.transaction((tx) async {
      final store = stringMapStoreFactory.store(StoreNames.devices);
      final finder = Finder(filter: Filter.equals(DeviceEntity.kSceneIDFieldName, sceneID ?? _sceneManager.current.id));
      final records = await store.find(tx, finder: finder);
      final devices = records.map((record) => DeviceEntity.fromMap(record.key, record.value)).toList();
      return devices;
    });
  }

  @override
  bool get isDiscoverying => _kernel.isScanning;

  @override
  Future<void> startDiscovery({Duration? timeout, CancellationToken? cancelToken}) async {
    assert(!_kernel.isScanning);
    await _kernel.startDevicesScanning(timeout: timeout, cancelToken: cancelToken);
  }

  @override
  Future<void> stopDiscovery() async {
    assert(_kernel.isScanning);
    await _kernel.stopDevicesScanning();
  }

  Future<void> _onUnboundDeviceDiscovered(UnboundDeviceDiscoveredEvent event) async {
    logger?.i('Device discovered: ${event.matched}');
    assert(isInitialized);

    final networkInterface = await NetworkInterfaceHelper.inferNetworkInterface(event.matched.address.host);
    logger?.d('Inferred network interface for device ${event.matched.fingerprint}: $networkInterface');

    return await _db.transaction((tx) async {
      final existed = await singleOrDefaultByFingerprint(event.matched.fingerprint, tx: tx);
      if (existed != null) {
        final updates = <String, dynamic>{};
        if (event.matched.address != existed.address) {
          updates[DeviceEntity.kAddressFieldName] = event.matched.address.toString();
        }
        if (updates.isNotEmpty) {
          final store = stringMapStoreFactory.store(StoreNames.devices);
          final record = store.record(existed.id);
          await record.update(tx, updates);
        }
      } else {
        allDeviceEvents.fire(NewDeviceFoundEvent(event.matched));
      }
    });
  }

  @override
  WotThing getWotThing(String deviceID) {
    // Only return WotThings for devices that are already loaded (current scene)
    final wotThing = _wotThings[deviceID];
    if (wotThing == null) {
      throw StateError(
        'WotThing not found for device $deviceID. Ensure the device is in the current scene and WotThing was loaded successfully.',
      );
    }
    return wotThing;
  }

  @override
  bool hasWotThing(String deviceID) => _wotThings.containsKey(deviceID);

  @override
  Iterable<WotThing> get wotThingsInCurrentScene => _wotThings.values;

  @override
  Iterable<String> get deviceIDsWithWotThings => _wotThings.keys;

  @override
  int get wotThingCount => _wotThings.length;

  /// Handle scene change event - reload WotThings for new scene
  Future<void> _onCurrentSceneChanged(CurrentSceneChangedEvent event) async {
    logger?.i('Scene changed from ${event.from.name} to ${event.to.name}, reloading WotThings...');
    await reloadAllDevices();
  }

  /// Reload WotThings for current scene only
  Future<void> _reloadWotThingsForCurrentScene() async {
    // Dispose of all existing WotThings
    _disposeAllWotThings();

    // Load WotThings for devices in current scene
    await _loadWotThingsForCurrentScene();

    // Fire event to notify that devices for current scene have been reloaded
    final currentScene = _sceneManager.current;
    _globalBus.fire(CurrentSceneDevicesReloadedEvent(currentScene));
    logger?.d('Fired CurrentSceneDevicesReloadedEvent for scene: ${currentScene.name}');
  }

  /// Dispose all existing WotThings
  void _disposeAllWotThings() {
    for (final wotThing in _wotThings.values) {
      try {
        wotThing.dispose();
      } catch (e) {
        logger?.w('Failed to dispose WotThing: $e');
      }
    }
    _wotThings.clear();
    logger?.d('Disposed ${_wotThings.length} WotThings');
  }

  /// Dispose a single WotThing for a device
  void _disposeWotThing(String deviceID) {
    final wotThing = _wotThings[deviceID];
    if (wotThing != null) {
      try {
        wotThing.dispose();
        _wotThings.remove(deviceID);
        logger?.d('Disposed WotThing for device $deviceID');
      } catch (e) {
        logger?.w('Failed to dispose WotThing for device $deviceID: $e');
      }
    }
  }

  /// Load WotThings for devices in current scene
  Future<void> _loadWotThingsForCurrentScene() async {
    try {
      final devices = await fetchAllDevicesInScene();
      logger?.d('Loading WotThings for ${devices.length} devices in current scene');

      for (final device in devices) {
        try {
          final metaModule = _deviceModuleRegistry.metaModules[device.driverID];
          if (metaModule != null) {
            final wotThing = await metaModule.createWotThing(device, this, logger: logger);
            _wotThings[device.id] = wotThing;

            // If device is bound, sync WotThing with actual device state
            if (isBound(device.id)) {
              await _syncWotThingWithBoundDevice(device.id, wotThing);
            }
          }
        } catch (e) {
          logger?.w('Failed to create WotThing for device ${device.id}: $e');
        }
      }

      logger?.d('Successfully loaded ${_wotThings.length} WotThings');
    } catch (e) {
      logger?.e('Failed to load WotThings for current scene: $e');
    }
  }

  /// Load WotThing for a single device
  Future<void> _loadWotThingForDevice(DeviceEntity device, {bool replaceExisting = true}) async {
    try {
      final metaModule = _deviceModuleRegistry.metaModules[device.driverID];
      if (metaModule != null) {
        final wotThing = await metaModule.createWotThing(device, this, logger: logger);
        if (!replaceExisting && _wotThings.containsKey(device.id)) {
          return;
        }
        final oldThing = _wotThings[device.id];
        _wotThings[device.id] = wotThing;

        if (replaceExisting && oldThing != null && oldThing != wotThing) {
          try {
            oldThing.dispose();
          } catch (e) {
            logger?.w('Failed to dispose replaced WotThing for device ${device.id}: $e');
          }
        }

        // If device is bound, sync WotThing with actual device state
        if (isBound(device.id)) {
          await _syncWotThingWithBoundDevice(device.id, wotThing);
        }
        logger?.d('Successfully loaded WotThing for device ${device.id}');
      }
    } catch (e) {
      logger?.w('Failed to create WotThing for device ${device.id}: $e');
    }
  }

  /// Sync WotThing properties with actual device state
  Future<void> _syncWotThingWithBoundDevice(String deviceID, WotThing wotThing) async {
    try {
      // This is where we would sync WotThing properties with actual device state
      // For now, we'll leave this as a placeholder for future implementation
      logger?.d('WotThing synced for device $deviceID');
    } catch (e) {
      logger?.w('Failed to sync WotThing for device $deviceID: $e');
    }
  }
}
