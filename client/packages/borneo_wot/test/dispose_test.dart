import 'package:test/test.dart';
import 'package:borneo_wot/property.dart';
import 'package:borneo_wot/value.dart';
import 'package:borneo_wot/thing.dart';

void main() {
  group('Dispose Functionality', () {
    test('WotProperty dispose should dispose its value', () {
      final thing = WotThing(id: 'test', title: 'Test', type: 'Test', description: 'Test');
      final value = WotValue<int>(initialValue: 42);
      final property = WotProperty<int>(thing: thing, name: 'test', value: value, metadata: WotPropertyMetadata());

      expect(value.isDisposed, isFalse);

      property.dispose();

      expect(value.isDisposed, isTrue);
    });

    test('WotThing dispose should dispose all its properties', () {
      final thing = WotThing(id: 'test', title: 'Test', type: 'Test', description: 'Test');
      final value1 = WotValue<int>(initialValue: 42);
      final value2 = WotValue<String>(initialValue: 'hello');

      final property1 = WotProperty<int>(thing: thing, name: 'test1', value: value1, metadata: WotPropertyMetadata());
      final property2 = WotProperty<String>(
        thing: thing,
        name: 'test2',
        value: value2,
        metadata: WotPropertyMetadata(),
      );

      thing.addProperty(property1);
      thing.addProperty(property2);

      expect(value1.isDisposed, isFalse);
      expect(value2.isDisposed, isFalse);

      thing.dispose();

      expect(value1.isDisposed, isTrue);
      expect(value2.isDisposed, isTrue);
    });
    test('WotValue should not accept updates after dispose', () async {
      final value = WotValue<int>(initialValue: 42);
      final updates = <int>[];

      value.onUpdate.listen(updates.add);

      value.set(100);
      await Future.delayed(Duration(milliseconds: 10));
      expect(updates, contains(100));

      value.dispose();
      expect(value.isDisposed, isTrue);

      // Should not update after dispose
      value.set(200);
      await Future.delayed(Duration(milliseconds: 10));
      expect(updates, hasLength(1)); // Should still be 1, not 2
    });
  });
}
