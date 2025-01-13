import 'package:borneo_app/models/base_entity.dart';

class DeviceGroupEntity with BaseEntity {
  static const String kIDFieldName = 'id';
  static const String kNameField = 'name';
  static const String kSceneIDFieldName = 'sceneID';
  static const String kNotesFieldName = 'notes';

  final String id;
  final String sceneID;
  final String name;
  final String notes;

  bool get isDummy => id == '';

  DeviceGroupEntity({
    required this.id,
    required this.sceneID,
    required this.name,
    this.notes = '',
  });

  factory DeviceGroupEntity.fromMap(String id, Map<String, dynamic> map) {
    return DeviceGroupEntity(
      id: id,
      sceneID: map[kSceneIDFieldName],
      name: map[kNameField],
      notes: map[kNotesFieldName],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      kSceneIDFieldName: sceneID,
      kNameField: name,
      kNotesFieldName: notes,
    };
  }
}
