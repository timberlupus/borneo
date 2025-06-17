import 'package:test/test.dart';
import 'package:borneo_wot/types.dart';

void main() {
  group('WotPrimitiveJsonType', () {
    test('toString returns correct string', () {
      expect(WotPrimitiveJsonType.nullType.toString(), 'null');
      expect(WotPrimitiveJsonType.boolean.toString(), 'boolean');
      expect(WotPrimitiveJsonType.object.toString(), 'object');
      expect(WotPrimitiveJsonType.array.toString(), 'array');
      expect(WotPrimitiveJsonType.number.toString(), 'number');
      expect(WotPrimitiveJsonType.integer.toString(), 'integer');
      expect(WotPrimitiveJsonType.string.toString(), 'string');
    });
    test('fromString returns correct enum', () {
      expect(WotPrimitiveJsonType.fromString('null'), WotPrimitiveJsonType.nullType);
      expect(WotPrimitiveJsonType.fromString('boolean'), WotPrimitiveJsonType.boolean);
      expect(WotPrimitiveJsonType.fromString('object'), WotPrimitiveJsonType.object);
      expect(WotPrimitiveJsonType.fromString('array'), WotPrimitiveJsonType.array);
      expect(WotPrimitiveJsonType.fromString('number'), WotPrimitiveJsonType.number);
      expect(WotPrimitiveJsonType.fromString('integer'), WotPrimitiveJsonType.integer);
      expect(WotPrimitiveJsonType.fromString('string'), WotPrimitiveJsonType.string);
    });
    test('fromString throws on unknown', () {
      expect(() => WotPrimitiveJsonType.fromString('foo'), throwsArgumentError);
    });
  });
}
