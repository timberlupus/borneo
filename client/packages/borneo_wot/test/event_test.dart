import 'package:test/test.dart';
import 'package:borneo_wot/event.dart';
import 'package:borneo_wot/thing.dart';
import 'package:borneo_wot/types.dart';

void main() {
  group('WotEventMetadata', () {
    test('creates metadata with all properties', () {
      final metadata = WotEventMetadata(
        type: 'number',
        atType: 'TemperatureEvent',
        unit: 'celsius',
        title: 'Temperature Alert',
        description: 'Triggered when temperature exceeds threshold',
        links: [WotLink(rel: 'event', href: '/events/temp-alert')],
        minimum: -50,
        maximum: 100,
        multipleOf: 0.1,
        enumValues: ['low', 'normal', 'high', 'critical'],
      );

      expect(metadata.type, equals('number'));
      expect(metadata.atType, equals('TemperatureEvent'));
      expect(metadata.unit, equals('celsius'));
      expect(metadata.title, equals('Temperature Alert'));
      expect(metadata.description, equals('Triggered when temperature exceeds threshold'));
      expect(metadata.links, hasLength(1));
      expect(metadata.minimum, equals(-50));
      expect(metadata.maximum, equals(100));
      expect(metadata.multipleOf, equals(0.1));
      expect(metadata.enumValues, hasLength(4));
    });

    test('creates metadata with minimal properties', () {
      final metadata = WotEventMetadata();

      expect(metadata.type, isNull);
      expect(metadata.atType, isNull);
      expect(metadata.unit, isNull);
      expect(metadata.title, isNull);
      expect(metadata.description, isNull);
      expect(metadata.links, isNull);
      expect(metadata.minimum, isNull);
      expect(metadata.maximum, isNull);
      expect(metadata.multipleOf, isNull);
      expect(metadata.enumValues, isNull);
    });
  });

  group('WotEvent', () {
    late WotThing thing;

    setUp(() {
      thing = WotThing(id: 'test-thing', title: 'Test Thing', type: ['TestDevice'], description: 'A test thing');
    });

    test('basic event properties', () {
      final eventData = {'temperature': 25.5, 'unit': 'celsius'};
      final event = WotEvent<Map<String, dynamic>>(thing: thing, name: 'temperatureChanged', data: eventData);

      expect(event.getName(), equals('temperatureChanged'));
      expect(event.getData(), equals(eventData));
      expect(event.getThing(), equals(thing));
      expect(event.getTime(), isNotNull);
      expect(event.getTime(), matches(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00'));
    });

    test('event without data', () {
      final event = WotEvent<String?>(thing: thing, name: 'buttonPressed');

      expect(event.getName(), equals('buttonPressed'));
      expect(event.getData(), isNull);
      expect(event.getThing(), equals(thing));
      expect(event.getTime(), isNotNull);
    });

    test('setHrefPrefix updates prefix correctly', () {
      final event = WotEvent<String>(thing: thing, name: 'testEvent', data: 'test-data');
      event.setHrefPrefix('/api/v1');
      expect(event.hrefPrefix, equals('/api/v1'));
    });

    test('asEventDescription with data', () {
      final eventData = {'sensor': 'temperature', 'value': 23.7, 'timestamp': '2025-06-15T12:00:00Z'};
      final event = WotEvent<Map<String, dynamic>>(thing: thing, name: 'sensorReading', data: eventData);

      final description = event.asEventDescription();

      expect(description, isA<Map<String, dynamic>>());
      expect(description['sensorReading'], isNotNull);
      expect(description['sensorReading']['timestamp'], isNotNull);
      expect(description['sensorReading']['data'], equals(eventData));
    });

    test('asEventDescription without data', () {
      final event = WotEvent<dynamic>(thing: thing, name: 'alertCleared');

      final description = event.asEventDescription();

      expect(description['alertCleared'], isNotNull);
      expect(description['alertCleared']['timestamp'], isNotNull);
      expect(description['alertCleared'].containsKey('data'), isFalse);
    });

    test('asEventDescription with null data explicitly', () {
      final event = WotEvent<String?>(thing: thing, name: 'nullEvent', data: null);

      final description = event.asEventDescription();

      expect(description['nullEvent']['timestamp'], isNotNull);
      expect(description['nullEvent'].containsKey('data'), isFalse);
    });

    test('events with different data types', () {
      // String data
      final stringEvent = WotEvent<String>(thing: thing, name: 'message', data: 'Hello World');
      expect(stringEvent.getData(), equals('Hello World'));

      // Numeric data
      final numberEvent = WotEvent<double>(thing: thing, name: 'measurement', data: 42.5);
      expect(numberEvent.getData(), equals(42.5));

      // Boolean data
      final boolEvent = WotEvent<bool>(thing: thing, name: 'status', data: true);
      expect(boolEvent.getData(), isTrue);

      // List data
      final listEvent = WotEvent<List<int>>(thing: thing, name: 'values', data: [1, 2, 3, 4, 5]);
      expect(listEvent.getData(), equals([1, 2, 3, 4, 5]));
    });

    test('event timestamp is consistent', () {
      final event1 = WotEvent<String>(thing: thing, name: 'event1', data: 'data1');
      final event2 = WotEvent<String>(thing: thing, name: 'event2', data: 'data2');

      // Events created at nearly the same time should have very close timestamps
      final time1 = DateTime.parse(event1.getTime().replaceAll('+00:00', 'Z'));
      final time2 = DateTime.parse(event2.getTime().replaceAll('+00:00', 'Z'));
      final difference = time2.difference(time1).inMilliseconds.abs();

      expect(difference, lessThan(100)); // Should be created within 100ms
    });

    test('event description structure matches expected format', () {
      final event = WotEvent<Map<String, String>>(
        thing: thing,
        name: 'deviceStatusChanged',
        data: {'status': 'online', 'reason': 'power_restored'},
      );

      final description = event.asEventDescription();

      // Verify structure matches Web of Things Event Description format
      expect(description.keys, hasLength(1));
      expect(description.containsKey('deviceStatusChanged'), isTrue);

      final eventDetails = description['deviceStatusChanged'];
      expect(eventDetails.containsKey('timestamp'), isTrue);
      expect(eventDetails.containsKey('data'), isTrue);
      expect(eventDetails['data'], isA<Map<String, String>>());
    });
    test('multiple events with same name but different data', () {
      final event1 = WotEvent<int>(thing: thing, name: 'counter', data: 1);
      final event2 = WotEvent<int>(thing: thing, name: 'counter', data: 2);
      final event3 = WotEvent<int>(thing: thing, name: 'counter', data: 3);

      expect(event1.getName(), equals(event2.getName()));
      expect(event2.getName(), equals(event3.getName()));

      expect(event1.getData(), equals(1));
      expect(event2.getData(), equals(2));
      expect(event3.getData(), equals(3));

      // All events should have valid timestamps
      expect(event1.getTime(), isNotNull);
      expect(event2.getTime(), isNotNull);
      expect(event3.getTime(), isNotNull);

      // Verify timestamp format
      expect(event1.getTime(), matches(r'\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}\+00:00'));
    });

    test('event with complex nested data structure', () {
      final complexData = {
        'device': {
          'id': 'sensor-001',
          'type': 'temperature',
          'location': {'room': 'living_room', 'floor': 1},
        },
        'readings': [
          {'time': '12:00:00', 'value': 22.1},
          {'time': '12:05:00', 'value': 22.3},
          {'time': '12:10:00', 'value': 22.0},
        ],
        'metadata': {'units': 'celsius', 'accuracy': 0.1, 'calibrated': true},
      };

      final event = WotEvent<Map<String, dynamic>>(thing: thing, name: 'sensorData', data: complexData);

      expect(event.getData(), equals(complexData));

      final description = event.asEventDescription();
      expect(description['sensorData']['data'], equals(complexData));

      // Verify nested structure is preserved
      final data = description['sensorData']['data'] as Map<String, dynamic>;
      expect(data['device']['location']['room'], equals('living_room'));
      expect(data['readings'], hasLength(3));
      expect(data['metadata']['calibrated'], isTrue);
    });

    test('event creation performance', () {
      final stopwatch = Stopwatch()..start();

      // Create many events to test performance
      final events = <WotEvent<int>>[];
      for (int i = 0; i < 1000; i++) {
        events.add(WotEvent<int>(thing: thing, name: 'perfTest', data: i));
      }

      stopwatch.stop();

      expect(events, hasLength(1000));
      expect(stopwatch.elapsedMilliseconds, lessThan(1000)); // Should be fast

      // Verify all events are properly created
      expect(events.first.getData(), equals(0));
      expect(events.last.getData(), equals(999));
    });
  });
}
