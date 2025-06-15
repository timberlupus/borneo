// Dart port of src/types.ts

enum WotPrimitiveJsonType {
  nullType,
  boolean,
  object,
  array,
  number,
  integer,
  string;

  @override
  String toString() {
    switch (this) {
      case WotPrimitiveJsonType.nullType:
        return 'null';
      case WotPrimitiveJsonType.boolean:
        return 'boolean';
      case WotPrimitiveJsonType.object:
        return 'object';
      case WotPrimitiveJsonType.array:
        return 'array';
      case WotPrimitiveJsonType.number:
        return 'number';
      case WotPrimitiveJsonType.integer:
        return 'integer';
      case WotPrimitiveJsonType.string:
        return 'string';
    }
  }

  static WotPrimitiveJsonType fromString(String value) {
    switch (value) {
      case 'null':
        return WotPrimitiveJsonType.nullType;
      case 'boolean':
        return WotPrimitiveJsonType.boolean;
      case 'object':
        return WotPrimitiveJsonType.object;
      case 'array':
        return WotPrimitiveJsonType.array;
      case 'number':
        return WotPrimitiveJsonType.number;
      case 'integer':
        return WotPrimitiveJsonType.integer;
      case 'string':
        return WotPrimitiveJsonType.string;
      default:
        throw ArgumentError('Unknown WotPrimitiveJsonType: $value');
    }
  }
}

typedef WotAnyType = Object?;

class WotLink {
  final String rel;
  final String href;
  final String? mediaType;
  WotLink({required this.rel, required this.href, this.mediaType});
}

abstract class WotSubscriber {
  void send(String message);
}
