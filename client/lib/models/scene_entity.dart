import 'package:borneo_app/models/base_entity.dart';

class SceneEntity with BaseEntity, EntityWithLastAccessTime {
  static const String kNameField = 'name';
  static const String kNotesFieldName = 'notes';
  static const String kIsCurrent = 'isCurrent';
  static const String kLastAccessTime = 'lastAccessTime';
  static const String kImageIDFieldName = 'imageID';
  static const String kImagePathFieldName = 'imagePath';

  final String id;
  final String name;
  final bool isCurrent;
  final String? imageID;
  final String? imagePath;
  final String notes;

  SceneEntity({
    required this.id,
    required this.name,
    required this.isCurrent,
    required DateTime lastAccessTime,
    this.imageID,
    this.imagePath,
    this.notes = '',
  }) {
    super.lastAccessTime = lastAccessTime;
  }

  factory SceneEntity.fromMap(String id, Map<String, dynamic> map) {
    return SceneEntity(
      id: id,
      name: map[kNameField],
      isCurrent: map[kIsCurrent],
      lastAccessTime: DateTime.fromMillisecondsSinceEpoch(map[kLastAccessTime]),
      imageID: map[kImageIDFieldName],
      imagePath: map[kImagePathFieldName],
      notes: map[kNotesFieldName],
    );
  }

  factory SceneEntity.newDefault({String name = 'Home'}) =>
      SceneEntity(id: BaseEntity.generateID(), name: name, isCurrent: true, lastAccessTime: DateTime.now());

  Map<String, dynamic> toMap() {
    return {
      kNameField: name,
      kIsCurrent: isCurrent,
      kLastAccessTime: lastAccessTime.millisecondsSinceEpoch,
      kImageIDFieldName: imageID,
      kImagePathFieldName: imagePath,
      kNotesFieldName: notes,
    };
  }

  SceneEntity copyWith({
    String? name,
    bool? isCurrent,
    DateTime? lastAccessTime,
    String? imageID,
    String? imagePath,
    String? notes,
  }) {
    return SceneEntity(
      id: id,
      name: name ?? this.name,
      isCurrent: isCurrent ?? this.isCurrent,
      lastAccessTime: lastAccessTime ?? this.lastAccessTime,
      imageID: imageID ?? this.imageID,
      imagePath: imagePath ?? this.imagePath,
      notes: notes ?? this.notes,
    );
  }
}
