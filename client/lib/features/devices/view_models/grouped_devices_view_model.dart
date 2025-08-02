import 'dart:async';
import 'dart:collection';

import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/features/devices/models/device_entity.dart';
import 'package:borneo_app/core/models/scene_entity.dart';
import 'package:borneo_app/core/services/devices/device_module_registry.dart';
import 'package:event_bus/event_bus.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:synchronized/synchronized.dart';

import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/features/devices/models/events.dart';
import 'package:borneo_app/core/services/scene_manager.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/features/devices/view_models/group_view_model.dart';

import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/shared/view_models/base_view_model.dart';

import '../../../core/models/events.dart';

class GroupedDevicesViewModel extends BaseViewModel with ViewModelEventBusMixin, ViewModelInitFutureMixin {
  final IClock clock;
  final ISceneManager _sceneManager;
  final IGroupManager _groupManager;
  final IDeviceManager _deviceManager;
  final IDeviceModuleRegistry _deviceModuleRegistry;
  final CancellationToken _cancellationToken = CancellationToken();
  final Lock _deviceOperLock = Lock();
  bool _isInitialized = false;

  // Getter for loading state
  bool get isInitialized => _isInitialized;
  // Getter for error message

  bool get isEmpty => _groups.isEmpty;
  bool get isLoading => isBusy;

  // Getter for users list
  final List<GroupViewModel> _groups = [];
  List<GroupViewModel> get groups => UnmodifiableListView(_groups);

  GroupViewModel get dummyGroup => _groups.singleWhere((g) => g.isDummy);

  SceneEntity get currentScene => _sceneManager.current;

  late final StreamSubscription<NewDeviceEntityAddedEvent> _deviceAddedEventSub;
  late final StreamSubscription<DeviceEntityDeletedEvent> _deviceDeletedEventSub;
  late final StreamSubscription<CurrentSceneChangedEvent> _currentSceneChangedEventSub;

  // Device group event subscriptions
  late final StreamSubscription<DeviceGroupCreatedEvent> _deviceGroupCreatedEventSub;
  late final StreamSubscription<DeviceGroupDeletedEvent> _deviceGroupDeletedEventSub;
  late final StreamSubscription<DeviceGroupUpdatedEvent> _deviceGroupUpdatedEventSub;

  GroupedDevicesViewModel(
    EventBus globalEventBus,
    this._sceneManager,
    this._groupManager,
    this._deviceManager,
    this._deviceModuleRegistry, {
    required this.clock,
    super.logger,
  }) {
    super.globalEventBus = globalEventBus;
    _deviceAddedEventSub = _deviceManager.allDeviceEvents.on<NewDeviceEntityAddedEvent>().listen(
      (event) => _onNewDeviceEntityAdded(event),
    );
    _deviceDeletedEventSub = _deviceManager.allDeviceEvents.on<DeviceEntityDeletedEvent>().listen(
      (event) => _onDeviceDeleted(event),
    );
    _currentSceneChangedEventSub = super.globalEventBus.on<CurrentSceneChangedEvent>().listen(_onCurrentSceneChanged);

    _deviceGroupCreatedEventSub = super.globalEventBus.on<DeviceGroupCreatedEvent>().listen(_onDeviceGroupCreated);

    _deviceGroupDeletedEventSub = super.globalEventBus.on<DeviceGroupDeletedEvent>().listen(_onDeviceGroupDeleted);

    _deviceGroupUpdatedEventSub = super.globalEventBus.on<DeviceGroupUpdatedEvent>().listen(_onDeviceGroupUpdated);
  }

  Future<void> initialize() async {
    assert(!isInitialized);
    super.setBusy(true, notify: false);
    try {
      await _reloadAll();
    } on CancelledException {
      logger?.i("Initialization future cancelled");
    } finally {
      _isInitialized = true;
      super.setBusy(false, notify: false);
    }
  }

  @override
  void dispose() {
    _cancellationToken.cancel();
    _deviceAddedEventSub.cancel();
    _deviceDeletedEventSub.cancel();
    _currentSceneChangedEventSub.cancel();

    _deviceGroupCreatedEventSub.cancel();
    _deviceGroupDeletedEventSub.cancel();
    _deviceGroupUpdatedEventSub.cancel();

    super.dispose();
  }

  Future<void> refresh({bool probeOfflineDevices = false}) async {
    if (isBusy) {
      return;
    }
    _tryReloadAll();
  }

  Future<void> _tryReloadAll() async {
    if (isBusy) {
      return;
    }

    super.setBusy(true);

    try {
      await _reloadAll();
    } on CancelledException {
      logger?.i("Refreshing task cancelled");
    } finally {
      super.setBusy(false);
    }
  }

  void _clearAllItems() {
    for (final g in _groups) {
      g.clearDevices();
      g.dispose();
    }
    _groups.clear();
  }

  Future<void> _reloadAll() async {
    final groupEntities = await _groupManager.fetchAllGroupsInCurrentScene().asCancellable(_cancellationToken);
    final deviceEntities = await _deviceManager.fetchAllDevicesInScene().asCancellable(_cancellationToken);

    _clearAllItems();

    final newDummyGroup = GroupViewModel(
      DeviceGroupEntity(id: '', sceneID: _sceneManager.current.id, name: 'Ungrouped devices'),
      clock: this.clock,
    );

    _groups.addAll(groupEntities.map((g) => GroupViewModel(g, clock: this.clock)).followedBy([newDummyGroup]));

    // Build device group mapping for efficient assignment
    final groupMap = {for (final group in _groups) group.id: group};

    for (final deviceEntity in deviceEntities) {
      final metaModule = _deviceModuleRegistry.metaModules[deviceEntity.driverID];
      if (metaModule != null) {
        final deviceVM = metaModule.createSummaryVM(deviceEntity, _deviceManager, globalEventBus);
        final targetGroup = deviceEntity.groupID != null ? groupMap[deviceEntity.groupID] : newDummyGroup;

        if (targetGroup != null) {
          targetGroup.addDevice(deviceVM);
        }
      }
    }
  }

  Future<void> changeDeviceGroup(DeviceEntity device, String? newGroupID) async {
    return await _deviceOperLock.synchronized(() async {
      if (isDisposed) return;

      final originalGroupVM = _groups.singleWhere((g) => g.devices.any((d) => d.deviceEntity.id == device.id));
      final newGroupVM = newGroupID != null ? _groups.singleWhere((g) => g.id == newGroupID) : dummyGroup;
      final deviceVM = originalGroupVM.devices.singleWhere((d) => d.deviceEntity.id == device.id);

      if (identical(originalGroupVM, newGroupVM)) {
        return;
      }

      try {
        // 1. Update the database first
        await _deviceManager.moveToGroup(device.id, newGroupVM.id);

        // 2. After confirming the database update, atomically update the in-memory state
        originalGroupVM.removeDevice(deviceVM);
        newGroupVM.insertDevice(0, deviceVM);

        // 3. Only notify the relevant groups to update, reducing global refreshes
        originalGroupVM.notifyListeners();
        newGroupVM.notifyListeners();

        logger?.i('Device ${device.name} moved from ${originalGroupVM.name} to ${newGroupVM.name}');
      } catch (e, stackTrace) {
        // Reload all data to maintain consistency in case of failure
        logger?.e('Failed to change device group, reloading all devices', error: e, stackTrace: stackTrace);
        await _reloadAll();
        notifyAppError('Failed to change the group for device "${device.name}"', error: e, stackTrace: stackTrace);
      }
    });
  }

  Future<void> _onNewDeviceEntityAdded(NewDeviceEntityAddedEvent event) async {
    if (isDisposed) return;

    try {
      final metaModule = _deviceModuleRegistry.metaModules[event.device.driverID];
      if (metaModule != null) {
        final deviceVM = metaModule.createSummaryVM(event.device, _deviceManager, globalEventBus);

        GroupViewModel targetGroup;
        if (event.device.groupID != null) {
          targetGroup = _groups.singleWhere((g) => g.id == event.device.groupID);
        } else {
          targetGroup = dummyGroup;
        }

        targetGroup.addDevice(deviceVM);
        logger?.i('Device ${event.device.name} added to group ${targetGroup.name}');
      }
    } catch (e, stackTrace) {
      logger?.e('Failed to add device incrementally, falling back to full reload', error: e, stackTrace: stackTrace);
      await _tryReloadAll();
    }
    // Notify only when necessary
    if (!isDisposed) {
      notifyListeners();
    }
  }

  Future<void> _onDeviceDeleted(DeviceEntityDeletedEvent event) async {
    if (isDisposed) return;

    final int changedGroupIndex = _groups.indexWhere((g) => g.devices.any((d) => d.deviceEntity.id == event.id));
    // Remove the deleted device from UI
    if (changedGroupIndex != -1) {
      final changedGroup = _groups[changedGroupIndex];
      final deviceToRemove = changedGroup.devices.firstWhere((d) => d.deviceEntity.id == event.id);
      deviceToRemove.dispose();
      changedGroup.removeDeviceById(event.id);
      // Notify only when necessary
      if (!isDisposed) {
        notifyListeners();
      }
    }
  }

  Future<void> deleteDevice(String id) async {
    assert(!isBusy);
    setBusy(true, notify: false);
    try {
      await _deviceManager.delete(id);
    } catch (e, stackTrace) {
      notifyAppError('Failed to delete device', error: e, stackTrace: stackTrace);
    } finally {
      setBusy(false, notify: false);
    }
  }

  void _onCurrentSceneChanged(CurrentSceneChangedEvent event) {
    if (!super.isDisposed && _isInitialized && !super.isBusy) {
      _tryReloadAll();
    }
  }

  void _onDeviceGroupCreated(DeviceGroupCreatedEvent event) {
    // Use reload with lock to prevent race conditions
    if (!isDisposed && !_isInitialized) return;

    _deviceOperLock.synchronized(() async {
      if (isDisposed) return;
      await _reloadAll();
      if (!isDisposed) {
        notifyListeners();
      }
    });
  }

  void _onDeviceGroupDeleted(DeviceGroupDeletedEvent event) {
    if (isDisposed) return;

    _deviceOperLock.synchronized(() async {
      if (isDisposed) return;

      // Avoid duplicate notifications - directly reload to ensure consistency
      await _reloadAll();
      if (!isDisposed) {
        notifyListeners();
      }
    });
  }

  void _onDeviceGroupUpdated(DeviceGroupUpdatedEvent event) {
    _deviceOperLock.synchronized(() async {
      if (isDisposed) return;

      // Simple reload to ensure data consistency
      await _reloadAll();
      if (!isDisposed) {
        notifyListeners();
      }
    });
  }
}
