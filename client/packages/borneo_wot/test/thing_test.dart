import 'package:test/test.dart';
import 'package:borneo_wot/thing.dart';
import 'package:borneo_wot/property.dart';
import 'package:borneo_wot/action.dart';
import 'package:borneo_wot/event.dart';
import 'package:borneo_wot/value.dart';
import 'package:borneo_wot/types.dart';

// Test action for action testing
class TestThingAction extends WotAction<dynamic> {
  bool _executed = false;

  TestThingAction({required super.id, required super.thing, required super.name, required super.input});

  bool get wasExecuted => _executed;

  @override
  Future<void> performAction() async {
    await Future.delayed(Duration(milliseconds: 10));
    _executed = true;
  }
}

// Mock subscriber for testing notifications
class MockSubscriber extends WotSubscriber {
  final List<String> receivedMessages = [];

  @override
  void send(String message) {
    receivedMessages.add(message);
  }
}

void main() {
  group('WotThing', () {
    late WotThing thing;

    setUp(() {
      thing = WotThing('test-thing-id', 'Test Thing', ['TestDevice'], 'A test thing for testing');
    });

    group('Constructor and Basic Properties', () {
      test('constructor with string type', () {
        final singleTypeThing = WotThing('id1', 'TestThing', 'SingleType', 'desc');
        expect(singleTypeThing.getId(), equals('id1'));
        expect(singleTypeThing.getTitle(), equals('TestThing'));
        expect(singleTypeThing.getType(), equals(['SingleType']));
        expect(singleTypeThing.getDescription(), equals('desc'));
        expect(singleTypeThing.getContext(), equals('https://webthings.io/schemas'));
      });

      test('constructor with list type', () {
        final multiTypeThing = WotThing('id2', 'MultiThing', ['TypeA', 'TypeB'], 'multi desc');
        expect(multiTypeThing.getType(), equals(['TypeA', 'TypeB']));
      });

      test('constructor with empty description', () {
        final noDescThing = WotThing('id3', 'NoDesc', ['Type'], '');
        expect(noDescThing.getDescription(), equals(''));
      });

      test('basic getters return correct values', () {
        expect(thing.getId(), equals('test-thing-id'));
        expect(thing.getTitle(), equals('Test Thing'));
        expect(thing.getType(), equals(['TestDevice']));
        expect(thing.getDescription(), equals('A test thing for testing'));
        expect(thing.getContext(), equals('https://webthings.io/schemas'));
        expect(thing.getHref(), equals('/'));
        expect(thing.getUiHref(), isNull);
      });
    });

    group('Thing Description', () {
      test('asThingDescription with minimal data', () {
        final desc = thing.asThingDescription();
        expect(desc['id'], equals('test-thing-id'));
        expect(desc['title'], equals('Test Thing'));
        expect(desc['@context'], equals('https://webthings.io/schemas'));
        expect(desc['@type'], equals(['TestDevice']));
        expect(desc['description'], equals('A test thing for testing'));
        expect(desc['properties'], isA<Map<String, dynamic>>());
        expect(desc['actions'], isA<Map<String, dynamic>>());
        expect(desc['events'], isA<Map<String, dynamic>>());
        expect(desc['links'], isA<List>());

        final links = desc['links'] as List;
        expect(links, hasLength(3));
        expect(links.any((link) => link['rel'] == 'properties'), isTrue);
        expect(links.any((link) => link['rel'] == 'actions'), isTrue);
        expect(links.any((link) => link['rel'] == 'events'), isTrue);
      });

      test('asThingDescription with UI href', () {
        thing.setUiHref('/ui/thing');
        final desc = thing.asThingDescription();

        final links = desc['links'] as List;
        expect(links, hasLength(4));
        expect(links.any((link) => link['rel'] == 'alternate' && link['mediaType'] == 'text/html'), isTrue);
      });

      test('asThingDescription excludes description when empty', () {
        final emptyDescThing = WotThing('id', 'title', ['type'], '');
        final desc = emptyDescThing.asThingDescription();
        expect(desc.containsKey('description'), isFalse);
      });
    });

    group('Href Management', () {
      test('setHrefPrefix updates all hrefs', () {
        final property = WotProperty<int>(
          thing: thing,
          name: 'testProp',
          value: WotValue<int>(42),
          metadata: WotPropertyMetadata(),
        );
        thing.addProperty(property);

        thing.setHrefPrefix('/api/v1');
        expect(thing.getHref(), equals('/api/v1'));
        expect(property.getHref(), startsWith('/api/v1'));
      });

      test('setUiHref and getUiHref', () {
        expect(thing.getUiHref(), isNull);
        thing.setUiHref('/ui/custom');
        expect(thing.getUiHref(), equals('/ui/custom'));
      });

      test('href prefix affects thing description links', () {
        thing.setHrefPrefix('/api/v2');
        final desc = thing.asThingDescription();
        final links = desc['links'] as List;

        expect(links.any((link) => link['href'] == '/api/v2/properties'), isTrue);
        expect(links.any((link) => link['href'] == '/api/v2/actions'), isTrue);
        expect(links.any((link) => link['href'] == '/api/v2/events'), isTrue);
      });
    });

    group('Property Management', () {
      late WotProperty<int> testProperty;
      late WotPropertyMetadata metadata;

      setUp(() {
        metadata = WotPropertyMetadata(type: 'integer', title: 'Test Property', minimum: 0, maximum: 100);
        testProperty = WotProperty<int>(
          thing: thing,
          name: 'temperature',
          value: WotValue<int>(25),
          metadata: metadata,
        );
      });

      test('addProperty and findProperty', () {
        thing.addProperty(testProperty);

        final found = thing.findProperty('temperature');
        expect(found, equals(testProperty));
        expect(found?.getName(), equals('temperature'));
      });

      test('removeProperty', () {
        thing.addProperty(testProperty);
        expect(thing.findProperty('temperature'), isNotNull);

        thing.removeProperty(testProperty);
        expect(thing.findProperty('temperature'), isNull);
      });

      test('hasProperty', () {
        expect(thing.hasProperty('temperature'), isFalse);
        thing.addProperty(testProperty);
        expect(thing.hasProperty('temperature'), isTrue);
      });

      test('getProperty and setProperty', () {
        thing.addProperty(testProperty);

        expect(thing.getProperty('temperature'), equals(25));
        thing.setProperty('temperature', 30);
        expect(thing.getProperty('temperature'), equals(30));
      });

      test('getProperty with non-existent property', () {
        expect(thing.getProperty('nonexistent'), isNull);
      });

      test('setProperty with non-existent property does nothing', () {
        // Should not throw an exception
        thing.setProperty('nonexistent', 42);
        expect(thing.getProperty('nonexistent'), isNull);
      });

      test('getProperties returns all property values', () {
        final prop1 = WotProperty<int>(thing: thing, name: 'temp', value: WotValue<int>(25), metadata: metadata);
        final prop2 = WotProperty<String>(
          thing: thing,
          name: 'status',
          value: WotValue<String>('on'),
          metadata: WotPropertyMetadata(),
        );

        thing.addProperty(prop1);
        thing.addProperty(prop2);

        final props = thing.getProperties();
        expect(props['temp'], equals(25));
        expect(props['status'], equals('on'));
        expect(props, hasLength(2));
      });

      test('getPropertyDescriptions', () {
        thing.addProperty(testProperty);
        final descriptions = thing.getPropertyDescriptions();

        expect(descriptions, hasLength(1));
        expect(descriptions['temperature'], isNotNull);
        expect(descriptions['temperature']!['type'], equals('integer'));
        expect(descriptions['temperature']!['title'], equals('Test Property'));
      });
    });

    group('Action Management', () {
      test('addAvailableAction and performAction', () {
        final metadata = WotActionMetadata(title: 'Test Action', description: 'A test action');
        thing.addAvailableAction(
          'testAction',
          metadata,
          (WotThing t, dynamic input) => TestThingAction(
            id: 'action-1',
            thing: t,
            name: 'testAction',
            input: input is Map<String, dynamic> ? input : null,
          ),
        );
        final action = thing.performAction('testAction', {'param': 'value'});
        expect(action, isNotNull);
        expect(action!.getName(), equals('testAction'));
        expect(action.getInput(), equals({'param': 'value'}));
      });

      test('performAction with non-existent action', () {
        final action = thing.performAction('nonexistent', {});
        expect(action, isNull);
      });
      test('getAction and removeAction', () {
        thing.addAvailableAction(
          'testAction',
          WotActionMetadata(),
          (WotThing t, dynamic input) => TestThingAction(
            id: 'action-1',
            thing: t,
            name: 'testAction',
            input: input is Map<String, dynamic> ? input : null,
          ),
        );

        final action = thing.performAction('testAction', {});
        expect(action, isNotNull);

        final found = thing.getAction('testAction', action!.getId());
        expect(found, equals(action));

        final removed = thing.removeAction('testAction', action.getId());
        expect(removed, isTrue);

        final notFound = thing.getAction('testAction', action.getId());
        expect(notFound, isNull);
      });

      test('removeAction with non-existent action', () {
        final removed = thing.removeAction('nonexistent', 'fake-id');
        expect(removed, isFalse);
      });
      test('getActionDescriptions', () {
        thing.addAvailableAction(
          'action1',
          WotActionMetadata(),
          (WotThing t, dynamic input) => TestThingAction(
            id: 'action-1',
            thing: t,
            name: 'action1',
            input: input is Map<String, dynamic> ? input : null,
          ),
        );

        final action1 = thing.performAction('action1', {'data': 1});
        final action2 = thing.performAction('action1', {'data': 2});

        final allDescriptions = thing.getActionDescriptions();
        expect(allDescriptions, hasLength(2));

        final action1Descriptions = thing.getActionDescriptions('action1');
        expect(action1Descriptions, hasLength(2));

        final nonexistentDescriptions = thing.getActionDescriptions('nonexistent');
        expect(nonexistentDescriptions, isEmpty);
      });
    });

    group('Event Management', () {
      test('addAvailableEvent and addEvent', () {
        final metadata = WotEventMetadata(type: 'object', title: 'Test Event');

        thing.addAvailableEvent('testEvent', metadata);

        final event = WotEvent<Map<String, dynamic>>(thing: thing, name: 'testEvent', data: {'data': 'value'});
        thing.addEvent(event);

        final descriptions = thing.getEventDescriptions('testEvent');
        expect(descriptions, hasLength(1));
        expect(descriptions.first['testEvent'], isNotNull);
      });

      test('getEventDescriptions', () {
        thing.addAvailableEvent('event1');
        thing.addAvailableEvent('event2');

        final event1 = WotEvent<String>(thing: thing, name: 'event1', data: 'data1');
        final event2a = WotEvent<String>(thing: thing, name: 'event2', data: 'data2a');
        final event2b = WotEvent<String>(thing: thing, name: 'event2', data: 'data2b');

        thing.addEvent(event1);
        thing.addEvent(event2a);
        thing.addEvent(event2b);

        final allEvents = thing.getEventDescriptions();
        expect(allEvents, hasLength(3));

        final event2Events = thing.getEventDescriptions('event2');
        expect(event2Events, hasLength(2));
      });
    });

    group('Subscriber Management', () {
      late MockSubscriber subscriber1;
      late MockSubscriber subscriber2;

      setUp(() {
        subscriber1 = MockSubscriber();
        subscriber2 = MockSubscriber();
      });

      test('addSubscriber and removeSubscriber', () {
        thing.addSubscriber(subscriber1);
        thing.addSubscriber(subscriber2);

        // Test property notification
        final property = WotProperty<int>(
          thing: thing,
          name: 'temp',
          value: WotValue<int>(25),
          metadata: WotPropertyMetadata(),
        );
        thing.addProperty(property);
        thing.propertyNotify(property);

        expect(subscriber1.receivedMessages, hasLength(1));
        expect(subscriber2.receivedMessages, hasLength(1));

        thing.removeSubscriber(subscriber1);
        thing.propertyNotify(property);

        expect(subscriber1.receivedMessages, hasLength(1)); // No new messages
        expect(subscriber2.receivedMessages, hasLength(2)); // One new message
      });

      test('addEventSubscriber and removeEventSubscriber', () {
        thing.addAvailableEvent('testEvent');
        thing.addEventSubscriber('testEvent', subscriber1);
        thing.addEventSubscriber('testEvent', subscriber2);

        final event = WotEvent<String>(thing: thing, name: 'testEvent', data: 'test data');
        thing.eventNotify(event);

        expect(subscriber1.receivedMessages, hasLength(1));
        expect(subscriber2.receivedMessages, hasLength(1));

        thing.removeEventSubscriber('testEvent', subscriber1);
        thing.eventNotify(event);

        expect(subscriber1.receivedMessages, hasLength(1)); // No new messages
        expect(subscriber2.receivedMessages, hasLength(2)); // One new message
      });

      test('removeSubscriber removes from all events', () {
        thing.addAvailableEvent('event1');
        thing.addAvailableEvent('event2');
        thing.addEventSubscriber('event1', subscriber1);
        thing.addEventSubscriber('event2', subscriber1);

        thing.removeSubscriber(subscriber1);

        final event1 = WotEvent<String>(thing: thing, name: 'event1', data: 'data');
        final event2 = WotEvent<String>(thing: thing, name: 'event2', data: 'data');

        thing.eventNotify(event1);
        thing.eventNotify(event2);

        expect(subscriber1.receivedMessages, isEmpty);
      });
    });

    group('Notification System', () {
      late MockSubscriber subscriber;
      late WotProperty<int> property;

      setUp(() {
        subscriber = MockSubscriber();
        thing.addSubscriber(subscriber);
        property = WotProperty<int>(
          thing: thing,
          name: 'temp',
          value: WotValue<int>(25),
          metadata: WotPropertyMetadata(),
        );
        thing.addProperty(property);
      });

      test('propertyNotify sends correct message format', () {
        thing.propertyNotify(property);

        expect(subscriber.receivedMessages, hasLength(1));
        final message = subscriber.receivedMessages.first;
        expect(message, contains('messageType'));
        expect(message, contains('propertyStatus'));
        expect(message, contains('temp'));
        expect(message, contains('25'));
      });

      test('actionNotify sends correct message format', () {
        thing.addAvailableAction(
          'testAction',
          WotActionMetadata(),
          (WotThing t, dynamic input) => TestThingAction(
            id: 'action-1',
            thing: t,
            name: 'testAction',
            input: input is Map<String, dynamic> ? input : null,
          ),
        );

        final action = thing.performAction('testAction', {})!;

        // Check if notification was sent (performAction calls actionNotify)
        expect(subscriber.receivedMessages, hasLength(1));
        final message = subscriber.receivedMessages.first;
        expect(message, contains('messageType'));
        expect(message, contains('actionStatus'));
      });

      test('eventNotify sends correct message format', () {
        thing.addAvailableEvent('testEvent');
        thing.addEventSubscriber('testEvent', subscriber);

        final event = WotEvent<String>(thing: thing, name: 'testEvent', data: 'test data');
        thing.eventNotify(event);

        expect(subscriber.receivedMessages, hasLength(1));
        final message = subscriber.receivedMessages.first;
        expect(message, contains('messageType'));
        expect(message, contains('event'));
        expect(message, contains('testEvent'));
      });

      test('eventNotify with unavailable event does nothing', () {
        final event = WotEvent<String>(thing: thing, name: 'unavailableEvent', data: 'data');
        thing.eventNotify(event);

        expect(subscriber.receivedMessages, isEmpty);
      });

      test('notification error handling', () {
        // Create a subscriber that throws an error
        final errorSubscriber = _ErrorSubscriber();
        thing.addSubscriber(errorSubscriber);

        // Should not throw an exception
        expect(() => thing.propertyNotify(property), returnsNormally);
      });
    });

    group('Integration Tests', () {
      test('complete thing workflow', () {
        // Set up thing with properties, actions, and events
        final tempProperty = WotProperty<double>(
          thing: thing,
          name: 'temp',
          value: WotValue<double>(25.5),
          metadata: WotPropertyMetadata(),
        );
        thing.addProperty(tempProperty);
        thing.addAvailableAction(
          'setTemperature',
          WotActionMetadata(title: 'Set Temperature'),
          (WotThing t, dynamic input) => TestThingAction(
            id: 'set-temp',
            thing: t,
            name: 'setTemperature',
            input: input is Map<String, dynamic> ? input : null,
          ),
        );

        thing.addAvailableEvent('temperatureChanged', WotEventMetadata(type: 'number'));

        // Set up subscriber
        final subscriber = MockSubscriber();
        thing.addSubscriber(subscriber);
        thing.addEventSubscriber('temperatureChanged', subscriber);

        // Set href prefix
        thing.setHrefPrefix('/api/things/temp-sensor');

        // Test property operation
        thing.setProperty('temperature', 25.5);
        expect(thing.getProperty('temperature'), equals(25.5));

        // Test action operation
        final action = thing.performAction('setTemperature', {'value': 22.0});
        expect(action, isNotNull);

        // Test event operation
        final event = WotEvent<double>(thing: thing, name: 'temperatureChanged', data: 22.0);
        thing.addEvent(event);

        // Verify thing description
        final description = thing.asThingDescription();
        expect(description['properties'], hasLength(1));
        expect(description['actions'], hasLength(1));
        expect(description['events'], hasLength(1));

        // Verify links have correct href prefix
        final links = description['links'] as List;
        expect(links.every((link) => link['href'].toString().startsWith('/api/things/temp-sensor')), isTrue);

        // Verify notifications were sent
        expect(subscriber.receivedMessages, isNotEmpty);
      });

      test('thing with multiple properties and types', () {
        final smartLight = WotThing('smart-light-001', 'Smart LED Light', [
          'Light',
          'OnOffSwitch',
          'ColorControl',
        ], 'A smart LED light with color control');

        // Add multiple properties
        final onOffProp = WotProperty<bool>(
          thing: thing,
          name: 'on',
          value: WotValue<bool>(true),
          metadata: WotPropertyMetadata(),
        );
        final brightnessProp = WotProperty<int>(
          thing: thing,
          name: 'brightness',
          value: WotValue<int>(100),
          metadata: WotPropertyMetadata(),
        );
        final colorProp = WotProperty<String>(
          thing: thing,
          name: 'color',
          value: WotValue<String>('red'),
          metadata: WotPropertyMetadata(),
        );

        smartLight.addProperty(onOffProp);
        smartLight.addProperty(brightnessProp);
        smartLight.addProperty(colorProp);

        // Test all properties
        expect(smartLight.getProperties(), hasLength(3));
        expect(smartLight.getProperty('on'), isFalse);
        expect(smartLight.getProperty('brightness'), equals(100));
        expect(smartLight.getProperty('color'), equals('#FFFFFF'));

        // Test property descriptions
        final propDescriptions = smartLight.getPropertyDescriptions();
        expect(propDescriptions, hasLength(3));
        expect(propDescriptions['brightness']!['minimum'], equals(0));
        expect(propDescriptions['brightness']!['maximum'], equals(100));

        // Test thing description
        final thingDesc = smartLight.asThingDescription();
        expect(thingDesc['@type'], equals(['Light', 'OnOffSwitch', 'ColorControl']));
        expect(thingDesc['properties'], hasLength(3));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('thing with null/empty values', () {
        // Test with minimal constructor
        final minimalThing = WotThing('min', 'Minimal', [], '');
        expect(minimalThing.getType(), isEmpty);
        expect(minimalThing.getDescription(), isEmpty);

        final desc = minimalThing.asThingDescription();
        expect(desc.containsKey('description'), isFalse);
      });

      test('property operations with invalid names', () {
        expect(thing.findProperty(''), isNull);
        expect(thing.getProperty(''), isNull);
        expect(thing.hasProperty(''), isFalse);
      });
      test('action operations with invalid data', () {
        thing.addAvailableAction(
          'testAction',
          WotActionMetadata(),
          (WotThing t, dynamic input) => TestThingAction(
            id: 'test',
            thing: t,
            name: 'testAction',
            input: input is Map<String, dynamic> ? input : null,
          ),
        );

        // Test with null input
        final action = thing.performAction('testAction', null);
        expect(action, isNotNull);
        expect(action!.getInput(), isNull);
      });

      test('concurrent property modifications', () {
        final property = WotProperty<int>(
          thing: thing,
          name: 'counter',
          value: WotValue<int>(0),
          metadata: WotPropertyMetadata(),
        );
        thing.addProperty(property);

        // Simulate concurrent modifications
        for (int i = 0; i < 100; i++) {
          thing.setProperty('counter', i);
        }

        expect(thing.getProperty('counter'), isA<int>());
        expect(thing.getProperty('counter'), greaterThanOrEqualTo(0));
        expect(thing.getProperty('counter'), lessThan(100));
      });
    });
  });
}

// Helper class for error testing
class _ErrorSubscriber extends WotSubscriber {
  @override
  void send(String message) {
    throw Exception('Subscriber error');
  }
}
