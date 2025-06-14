import 'package:uuid/uuid.dart';

mixin BaseEntity {
  static String generateID() => Uuid().v6();
}

mixin EntityWithLastAccessTime {
  late final DateTime lastAccessTime;
}
