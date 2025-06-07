import 'package:borneo_app/models/base_entity.dart';
import 'package:borneo_kernel_abstractions/device.dart';
import 'package:borneo_kernel_abstractions/models/driver_data.dart';
import 'package:cancellation_token/cancellation_token.dart';
import 'package:synchronized/synchronized.dart';

class DeviceEntity extends Device with BaseEntity {
  static final String kNameFieldName = "name";
  static final String kSceneIDFieldName = "sceneID";
  static final String kGroupIDFieldName = "groupID";
  static final String kFngerprintFieldName = "fingerprint";
  static final String kAddressFieldName = "address";

  final _lock = Lock();
  DriverData? _driverData;

  final String sceneID;
  final String? groupID;
  final String driverID;
  final String compatible;
  final String name;
  final String model;

  DeviceEntity({
    required super.id,
    required super.address,
    required super.fingerprint,
    required this.sceneID,
    required this.driverID,
    required this.compatible,
    required this.name,
    required this.model,
    this.groupID,
  });

  factory DeviceEntity.fromMap(String id, Map<String, dynamic> map) {
    return DeviceEntity(
      id: id,
      sceneID: map[kSceneIDFieldName],
      groupID: map[kGroupIDFieldName],
      address: Uri.parse(map[kAddressFieldName]),
      compatible: map['compatible'],
      driverID: map['driverID'],
      fingerprint: map[kFngerprintFieldName],
      name: map[kNameFieldName],
      model: map['model'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': super.id,
      kSceneIDFieldName: sceneID,
      kGroupIDFieldName: groupID,
      kAddressFieldName: address.toString(),
      'driverID': driverID,
      'compatible': compatible,
      kFngerprintFieldName: fingerprint,
      kNameFieldName: name,
      'model': model,
    };
  }

  @override
  dynamic get driverData => _driverData;

  @override
  Future<void> setDriverData(dynamic driverData, {CancellationToken? cancelToken}) async {
    await _lock
        .synchronized(() async {
          _driverData = driverData;
        })
        .asCancellable(cancelToken);
  }

  @override
  String toString() => 'Device(id: `$id`, name: `$name`, model: `$model`, uri: `$address`)';
}
