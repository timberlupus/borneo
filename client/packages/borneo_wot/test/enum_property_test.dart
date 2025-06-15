import 'package:test/test.dart';
import 'package:borneo_wot/property.dart';
import 'package:borneo_wot/thing.dart';
import 'package:borneo_wot/value.dart';

// 定义一个设备状态枚举
enum DeviceOperationMode {
  idle,
  active,
  maintenance,
  error;

  @override
  String toString() {
    switch (this) {
      case DeviceOperationMode.idle:
        return 'idle';
      case DeviceOperationMode.active:
        return 'active';
      case DeviceOperationMode.maintenance:
        return 'maintenance';
      case DeviceOperationMode.error:
        return 'error';
    }
  }

  static DeviceOperationMode fromString(String value) {
    switch (value) {
      case 'idle':
        return DeviceOperationMode.idle;
      case 'active':
        return DeviceOperationMode.active;
      case 'maintenance':
        return DeviceOperationMode.maintenance;
      case 'error':
        return DeviceOperationMode.error;
      default:
        throw ArgumentError('Unknown DeviceOperationMode: $value');
    }
  }

  static List<String> get allStringValues => DeviceOperationMode.values.map((e) => e.toString()).toList();
}

// 定义优先级枚举
enum Priority {
  low,
  medium,
  high,
  critical;

  @override
  String toString() => name;

  static Priority fromString(String value) {
    return Priority.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown Priority: $value'),
    );
  }

  static List<String> get allStringValues => Priority.values.map((e) => e.name).toList();
}

void main() {
  group('Enum Properties in WoT', () {
    late WotThing thing;

    setUp(() {
      thing = WotThing('test-device-001', 'Test Smart Device', [
        'TestDevice',
        'SmartDevice',
      ], 'A test device with enum properties');
    });

    test('Create property with enum values', () {
      // Create a string property with enum constraint
      final operationModeProperty = WotProperty<String>(
        thing: thing,
        name: 'operationMode',
        value: WotValue<String>(DeviceOperationMode.idle.toString()),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Operation Mode',
          description: 'Current operation mode of the device',
          enumValues: DeviceOperationMode.allStringValues,
          readOnly: false,
        ),
      );

      thing.addProperty(operationModeProperty);

      // Verify property creation
      expect(operationModeProperty.getName(), equals('operationMode'));
      expect(operationModeProperty.getValue(), equals('idle'));
      expect(operationModeProperty.getMetadata().enumValues, equals(['idle', 'active', 'maintenance', 'error']));
      expect(operationModeProperty.getMetadata().readOnly, isFalse);
    });

    test('Set and get enum property value', () {
      final priorityProperty = WotProperty<String>(
        thing: thing,
        name: 'priority',
        value: WotValue<String>(Priority.medium.toString()),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Priority Level',
          description: 'Priority level for device operations',
          enumValues: Priority.allStringValues,
          readOnly: false,
        ),
      );

      thing.addProperty(priorityProperty);

      // Test setting valid enum values
      priorityProperty.setValue(Priority.high.toString());
      expect(priorityProperty.getValue(), equals('high'));

      priorityProperty.setValue(Priority.critical.toString());
      expect(priorityProperty.getValue(), equals('critical'));

      // Verify enum value list
      expect(priorityProperty.getMetadata().enumValues, containsAll(['low', 'medium', 'high', 'critical']));
    });

    test('Property description contains enum info', () {
      final modeProperty = WotProperty<String>(
        thing: thing,
        name: 'deviceMode',
        value: WotValue<String>(DeviceOperationMode.active.toString()),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Device Mode',
          description: 'Current mode of operation',
          enumValues: DeviceOperationMode.allStringValues,
          readOnly: false,
        ),
      );

      thing.addProperty(modeProperty);

      final description = modeProperty.asPropertyDescription();

      expect(description['type'], equals('string'));
      expect(description['title'], equals('Device Mode'));
      expect(description['enum'], equals(['idle', 'active', 'maintenance', 'error']));
      expect(description['readOnly'], isFalse);
      expect(description['links'], isA<List>());
    });

    test('Read-only enum property', () {
      final statusProperty = WotProperty<String>(
        thing: thing,
        name: 'connectionStatus',
        value: WotValue<String>('connected'),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Connection Status',
          description: 'Current connection status',
          enumValues: ['connected', 'disconnected', 'connecting', 'error'],
          readOnly: true,
        ),
      );

      thing.addProperty(statusProperty);

      // Verify read-only property
      expect(statusProperty.getMetadata().readOnly, isTrue);

      // Attempting to set a read-only property should throw
      expect(() => statusProperty.setValue('disconnected'), throwsA(isA<Exception>()));
    });

    test('Enum property in Thing description', () {
      // Add multiple enum properties
      final operationModeProperty = WotProperty<String>(
        thing: thing,
        name: 'operationMode',
        value: WotValue<String>(DeviceOperationMode.idle.toString()),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Operation Mode',
          enumValues: DeviceOperationMode.allStringValues,
          readOnly: false,
        ),
      );
      final priorityProperty = WotProperty<String>(
        thing: thing,
        name: 'priority',
        value: WotValue<String>(Priority.low.toString()),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Priority',
          enumValues: Priority.allStringValues,
          readOnly: false,
        ),
      );

      thing.addProperty(operationModeProperty);
      thing.addProperty(priorityProperty);

      final thingDescription = thing.asThingDescription();

      // Verify Thing description contains properties
      expect(thingDescription['properties'], contains('operationMode'));
      expect(thingDescription['properties'], contains('priority'));

      // Verify property description contains enum info
      final operationModeDesc = thingDescription['properties']['operationMode'];
      expect(operationModeDesc['enum'], equals(['idle', 'active', 'maintenance', 'error']));

      final priorityDesc = thingDescription['properties']['priority'];
      expect(priorityDesc['enum'], equals(['low', 'medium', 'high', 'critical']));
    });
    test('Enum property value change listener', () async {
      var valueChangeCount = 0;
      String? lastValue;

      final modeProperty = WotProperty<String>(
        thing: thing,
        name: 'testMode',
        value: WotValue<String>(DeviceOperationMode.idle.toString()),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Test Mode',
          enumValues: DeviceOperationMode.allStringValues,
          readOnly: false,
        ),
      );

      thing.addProperty(modeProperty);

      // Listen for value changes
      modeProperty.value.onUpdate.listen((newValue) {
        valueChangeCount++;
        lastValue = newValue;
      });

      // Change value
      modeProperty.setValue(DeviceOperationMode.active.toString());

      // Wait for async event
      await Future.delayed(Duration(milliseconds: 10));

      expect(valueChangeCount, greaterThan(0));
      expect(lastValue, equals('active'));

      // Change value again
      modeProperty.setValue(DeviceOperationMode.maintenance.toString());
      await Future.delayed(Duration(milliseconds: 10));
      expect(lastValue, equals('maintenance'));
    });

    test('Complex enum property usage', () {
      // Create a mock smart thermostat device
      final thermostat = WotThing('thermostat-001', 'Smart Thermostat', [
        'Thermostat',
      ], 'A smart thermostat with multiple enum properties');

      // Work mode enum property
      final workModeProperty = WotProperty<String>(
        thing: thermostat,
        name: 'workMode',
        value: WotValue<String>('auto'),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Work Mode',
          description: 'Thermostat working mode',
          enumValues: ['auto', 'manual', 'schedule', 'vacation'],
          readOnly: false,
        ),
      );
      // Fan speed enum property
      final fanSpeedProperty = WotProperty<String>(
        thing: thermostat,
        name: 'fanSpeed',
        value: WotValue<String>('medium'),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'Fan Speed',
          description: 'Fan speed setting',
          enumValues: ['low', 'medium', 'high', 'auto'],
          readOnly: false,
        ),
      );
      // System status read-only enum property
      final systemStatusProperty = WotProperty<String>(
        thing: thermostat,
        name: 'systemStatus',
        value: WotValue<String>('idle'),
        metadata: WotPropertyMetadata(
          type: 'string',
          title: 'System Status',
          description: 'Current system status',
          enumValues: ['idle', 'heating', 'cooling', 'fan_only'],
          readOnly: true,
        ),
      );
      // Target temperature numeric property for comparison
      final targetTempProperty = WotProperty<double>(
        thing: thermostat,
        name: 'targetTemperature',
        value: WotValue<double>(22.0),
        metadata: WotPropertyMetadata(
          type: 'number',
          title: 'Target Temperature',
          description: 'Target temperature in Celsius',
          unit: '°C',
          minimum: 10,
          maximum: 35,
          readOnly: false,
        ),
      );

      thermostat.addProperty(workModeProperty);
      thermostat.addProperty(fanSpeedProperty);
      thermostat.addProperty(systemStatusProperty);
      thermostat.addProperty(targetTempProperty);

      // Verify all properties are added
      expect(thermostat.getProperty('workMode'), isNotNull);
      expect(thermostat.getProperty('fanSpeed'), isNotNull);
      expect(thermostat.getProperty('systemStatus'), isNotNull);
      expect(thermostat.getProperty('targetTemperature'), isNotNull);

      // Verify enum property constraints
      expect(workModeProperty.getMetadata().enumValues, equals(['auto', 'manual', 'schedule', 'vacation']));
      expect(fanSpeedProperty.getMetadata().enumValues, equals(['low', 'medium', 'high', 'auto']));

      // Verify numeric property constraints
      expect(targetTempProperty.getMetadata().minimum, equals(10));
      expect(targetTempProperty.getMetadata().maximum, equals(35));
      expect(targetTempProperty.getMetadata().unit, equals('°C'));

      // Test property value setting
      workModeProperty.setValue('manual');
      fanSpeedProperty.setValue('high');
      targetTempProperty.setValue(24.5);

      expect(workModeProperty.getValue(), equals('manual'));
      expect(fanSpeedProperty.getValue(), equals('high'));
      expect(targetTempProperty.getValue(), equals(24.5));

      // Verify Thing description integrity
      final description = thermostat.asThingDescription();
      expect(description['properties'], hasLength(4));
      expect(description['@type'], contains('Thermostat'));
    });
  });
}
