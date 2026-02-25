import 'package:borneo_app/features/devices/models/device_group_entity.dart';
import 'package:borneo_app/core/services/group_manager.dart';
import 'package:sembast/sembast.dart';

/// Simple stub that satisfies most tests without doing anything.
class StubGroupManager implements IGroupManager {
  @override
  bool get isInitialized => true;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> create({required String name, String notes = '', Transaction? tx}) async {}

  @override
  Future<void> update(String id, {required String name, String notes = '', Transaction? tx}) async {}

  @override
  Future<void> delete(String id, {Transaction? tx}) async {}

  @override
  Future<DeviceGroupEntity> fetch(String id, {Transaction? tx}) async {
    throw UnimplementedError();
  }

  @override
  Future<List<DeviceGroupEntity>> fetchAllGroupsInCurrentScene({Transaction? tx}) async => [];

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
