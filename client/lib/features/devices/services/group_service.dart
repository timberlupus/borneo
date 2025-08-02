import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';

/// Service for handling device group operations
/// This service decouples group management logic from view models
class GroupService {
  final DeviceManager _deviceManager;
  final IGroupManager _groupManager;

  GroupService(this._deviceManager, this._groupManager);

  /// Get all device groups in current scene
  Future<List<DeviceGroupEntity>> getGroups() async {
    return await _groupManager.fetchAllGroupsInCurrentScene();
  }

  /// Delete a device group and move devices to ungrouped
  Future<void> deleteGroup(String groupId) async {
    try {
      // Get all devices in this group
      final devices = await _deviceManager.fetchAllDevicesInScene();
      final devicesInGroup = devices.where((device) => device.groupID == groupId).toList();

      // Move devices to ungrouped (empty groupID)
      for (final device in devicesInGroup) {
        await _deviceManager.moveToGroup(device.id, '');
      }

      // Delete the group
      await _groupManager.delete(groupId);
    } catch (error) {
      throw Exception('Failed to delete group: $error');
    }
  }

  /// Create a new device group
  Future<void> createGroup(String name, String sceneId) async {
    try {
      await _groupManager.create(name: name);
    } catch (error) {
      throw Exception('Failed to create group: $error');
    }
  }

  /// Update device group name
  Future<void> updateGroup(String groupId, String newName) async {
    try {
      await _groupManager.update(groupId, name: newName);
    } catch (error) {
      throw Exception('Failed to update group: $error');
    }
  }

  /// Move device to a specific group
  Future<void> moveDeviceToGroup(String deviceId, String? groupId) async {
    try {
      await _deviceManager.moveToGroup(deviceId, groupId ?? '');
    } catch (error) {
      throw Exception('Failed to move device to group: $error');
    }
  }
}
