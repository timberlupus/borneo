import 'package:uuid/uuid.dart';

abstract class IEntity {
  String get id;
  set id(String id);

  static String generateID() => Uuid().v6().toString();

  Map<String, dynamic> toMap();
}
