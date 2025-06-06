import 'dart:async';

import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/models/scene_entity.dart';
import 'package:borneo_app/services/devices/device_module_registry.dart';
import 'package:borneo_kernel_abstractions/device_capability.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';
import 'package:cancellation_token/cancellation_token.dart';

import 'package:borneo_app/models/devices/device_group_entity.dart';
import 'package:borneo_app/models/devices/events.dart';
import 'package:borneo_app/services/scene_manager.dart';
import 'package:borneo_app/services/group_manager.dart';
import 'package:borneo_app/view_models/devices/device_summary_view_model.dart';
import 'package:borneo_app/view_models/devices/group_view_model.dart';

import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_app/view_models/base_view_model.dart';

import '../../models/events.dart';

class GroupedDevicesViewModel extends BaseViewModel with ViewModelEventBusMixin {
  final Logger? logger;
  final SceneManager _sceneManager;
  final GroupManager _groupManager;
  final DeviceManager _deviceManager;
  final IDeviceModuleRegistry _deviceModuleRegistry;
  final CancellationToken _cancellationToken = CancellationToken();
  bool _isInitialized = false;

  // Getter for loading state
  bool get isInitialized => _isInitialized;
  // Getter for error message

  bool get isEmpty => _groups.isEmpty;

  // Getter for users list
  final List<GroupViewModel> _groups = [];
  List<GroupViewModel> get groups => _groups;

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
    this.logger,
  }) {
    super.globalEventBus = globalEventBus;
    _deviceAddedEventSub = _deviceManager.deviceEvents.on<NewDeviceEntityAddedEvent>().listen(
      (event) => _onNewDeviceEntityAdded(event),
    );
    _deviceDeletedEventSub = _deviceManager.deviceEvents.on<DeviceEntityDeletedEvent>().listen(
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
      g.dispose();
    }
    _groups.clear();
  }

  Future<void> _reloadAll() async {
    final groupEntities = await _groupManager.fetchAllGroupsInCurrentScene().asCancellable(_cancellationToken);

    _clearAllItems();

    final dummyGroup = GroupViewModel(
      DeviceGroupEntity(id: '', sceneID: _sceneManager.current.id, name: 'Ungrouped devices'),
    );

    _groups.addAll(groupEntities.map((g) => GroupViewModel(g)).followedBy([dummyGroup]));

    final deviceEntities = await _deviceManager.fetchAllDevicesInScene().asCancellable(_cancellationToken);
    for (final deviceEntity in deviceEntities) {
      var isPowerOn = false;
      if (_deviceManager.isBound(deviceEntity.id)) {
        final bound = _deviceManager.getBoundDevice(deviceEntity.id);
        if (bound.api() is IPowerOnOffCapability) {
          isPowerOn = await bound.api<IPowerOnOffCapability>().getOnOff(deviceEntity); // TODO cancellable
        }
      }

      final deviceVM = DeviceSummaryViewModel(
        deviceEntity,
        await _deviceManager.getDeviceState(deviceEntity.id),
        _deviceManager,
        _deviceModuleRegistry,
        globalEventBus,
        isPowerOn,
      );
      if (deviceEntity.groupID != null) {
        final g = _groups.singleWhere((x) => x.id == deviceEntity.groupID);
        g.devices.add(deviceVM);
      } else {
        dummyGroup.devices.add(deviceVM);
      }
    }
  }

  Future<void> changeDeviceGroup(DeviceEntity device, String? newGroupID) async {
    final originalGroupVM = _groups.singleWhere((g) => g.devices.any((d) => d.id == device.id));
    final newGroupVM = newGroupID != null ? _groups.singleWhere((g) => g.id == newGroupID) : dummyGroup;
    final deviceVM = originalGroupVM.devices.singleWhere((d) => d.id == device.id);

    if (identical(originalGroupVM, newGroupVM)) {
      return;
    }
    try {
      await _deviceManager.moveToGroup(device.id, newGroupVM.id);
      newGroupVM.devices.insert(0, deviceVM);
      originalGroupVM.devices.removeWhere((d) => d.id == device.id);
    } catch (e, stackTrace) {
      notifyAppError('Failed to change the group for device "${device.name}"', error: e, stackTrace: stackTrace);
    } finally {
      newGroupVM.notifyListeners();
      originalGroupVM.notifyListeners();
      setBusy(false, notify: false);
    }
  }

  Future<void> _onNewDeviceEntityAdded(NewDeviceEntityAddedEvent event) async {
    await _tryReloadAll();
    notifyListeners();
  }

  Future<void> _onDeviceDeleted(DeviceEntityDeletedEvent event) async {
    final int changedGroupIndex = _groups.indexWhere((g) => g.devices.any((d) => d.id == event.id));
    // Remove the deleted device from UI
    if (changedGroupIndex != -1) {
      final changedGroup = _groups[changedGroupIndex];
      final deviceIndexToRemove = changedGroup.devices.indexWhere((d) => d.id == event.id);
      final deviceToRemove = changedGroup.devices[deviceIndexToRemove];
      deviceToRemove.dispose();
      changedGroup.devices.removeAt(deviceIndexToRemove);
      changedGroup.notifyListeners();
    }
    if (isEmpty) {
      notifyListeners();
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
    if (!isBusy) {
      _tryReloadAll();
      notifyListeners();
    }
  }

  void _onDeviceGroupDeleted(DeviceGroupDeletedEvent event) {
    if (!isBusy) {
      _tryReloadAll();
      notifyListeners();
    }
  }

  void _onDeviceGroupUpdated(DeviceGroupUpdatedEvent event) {
    for (final gvm in _groups) {
      if (gvm.id == event.group.id) {
        gvm.model = event.group;
        gvm.notifyListeners();
      }
    }
  }
}
