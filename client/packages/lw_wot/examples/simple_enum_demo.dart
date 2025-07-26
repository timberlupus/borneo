// simple_enum_demo.dart
// Simple demonstration of using Dart enum in lw_wot

import 'package:lw_wot/property.dart';
import 'package:lw_wot/thing.dart';
import 'package:lw_wot/value.dart';

// Define device state enum
enum DeviceState {
  offline,
  standby,
  active,
  maintenance;

  @override
  String toString() => name;

  static DeviceState fromString(String value) {
    return DeviceState.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown DeviceState: $value'),
    );
  }

  static List<String> get allValues => values.map((e) => e.name).toList();
}

// Define operation mode enum
enum OperationMode {
  manual,
  automatic,
  scheduled;

  @override
  String toString() => name;

  static OperationMode fromString(String value) {
    return OperationMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown OperationMode: $value'),
    );
  }

  static List<String> get allValues => values.map((e) => e.name).toList();
}

void main() {
  print('=== Example of using Dart Enum properties in lw_wot ===\n');

  // Create WoT Thing
  final device = WotThing(
    id: 'smart-device-001',
    title: 'Smart Device Controller',
    type: ['SmartDevice', 'Controller'],
    description: 'A smart device demonstrating enum properties',
  );

  // 1. Create device state enum property (read-only)
  final deviceStateProperty = WotProperty<String>(
    thing: device,
    name: 'deviceState',
    value: WotValue<String>(initialValue: DeviceState.standby.toString()),
    metadata: WotPropertyMetadata(
      type: 'string',
      title: 'Device State',
      description: 'Current state of the device',
      enumValues: DeviceState.allValues, // ['offline', 'standby', 'active', 'maintenance']
      readOnly: true, // Read-only, usually determined by internal device state
    ),
  );

  // 2. Create operation mode enum property (read-write)
  final operationModeProperty = WotProperty<String>(
    thing: device,
    name: 'operationMode',
    value: WotValue<String>(initialValue: OperationMode.automatic.toString()),
    metadata: WotPropertyMetadata(
      type: 'string',
      title: 'Operation Mode',
      description: 'How the device operates',
      enumValues: OperationMode.allValues, // ['manual', 'automatic', 'scheduled']
      readOnly: false, // Writable, user can change
    ),
  );

  // 3. Create other types of properties for comparison
  final temperatureProperty = WotProperty<double>(
    thing: device,
    name: 'temperature',
    value: WotValue<double>(initialValue: 22.5),
    metadata: WotPropertyMetadata(
      type: 'number',
      title: 'Temperature',
      description: 'Current temperature reading',
      unit: '°C',
      minimum: -40,
      maximum: 85,
      readOnly: true,
    ),
  );

  final enabledProperty = WotProperty<bool>(
    thing: device,
    name: 'enabled',
    value: WotValue<bool>(initialValue: true),
    metadata: WotPropertyMetadata(
      type: 'boolean',
      title: 'Enabled',
      description: 'Whether the device is enabled',
      readOnly: false,
    ),
  );

  // Add properties to device
  device.addProperty(deviceStateProperty);
  device.addProperty(operationModeProperty);
  device.addProperty(temperatureProperty);
  device.addProperty(enabledProperty);

  print('Device created with the following properties:');
  print('- deviceState (enum): ${deviceStateProperty.getValue()}');
  print('- operationMode (enum): ${operationModeProperty.getValue()}');
  print('- temperature (number): ${temperatureProperty.getValue()}°C');
  print('- enabled (boolean): ${enabledProperty.getValue()}');
  print('');

  // Demonstrate enum property usage
  print('=== Demonstrating enum property operations ===\n');

  // Listen to property changes
  operationModeProperty.value.onUpdate.listen((newMode) {
    print('Operation mode changed to: $newMode');

    // Execute different business logic based on mode
    final mode = OperationMode.fromString(newMode);
    switch (mode) {
      case OperationMode.manual:
        print('  -> Switched to manual mode, waiting for user instructions');
        break;
      case OperationMode.automatic:
        print('  -> Switched to automatic mode, starting automatic operation');
        break;
      case OperationMode.scheduled:
        print('  -> Switched to scheduled mode, executing tasks as planned');
        break;
    }
  });

  // Test changing enum values
  print('1. Current operation mode: ${operationModeProperty.getValue()}');

  print('2. Changing to manual mode...');
  operationModeProperty.setValue(OperationMode.manual.toString());

  print('3. Changing to scheduled mode...');
  operationModeProperty.setValue(OperationMode.scheduled.toString());

  // Simulate device state change (read-only property, can only be changed internally)
  print('\n4. Simulating device state change...');
  print('Current device state: ${deviceStateProperty.getValue()}');

  // Change state through internal logic
  deviceStateProperty.value.set(DeviceState.active.toString());
  print('Device state updated to: ${deviceStateProperty.getValue()}');

  // Display property description information
  print('\n=== Property Description Information ===\n');

  final deviceStateDesc = deviceStateProperty.asPropertyDescription();
  print('Device state property:');
  print('  Type: ${deviceStateDesc['type']}');
  print('  Enum values: ${deviceStateDesc['enum']}');
  print('  Read only: ${deviceStateDesc['readOnly']}');
  print('  Title: ${deviceStateDesc['title']}');
  print('');

  final operationModeDesc = operationModeProperty.asPropertyDescription();
  print('Operation mode property:');
  print('  Type: ${operationModeDesc['type']}');
  print('  Enum values: ${operationModeDesc['enum']}');
  print('  Read only: ${operationModeDesc['readOnly']}');
  print('  Title: ${operationModeDesc['title']}');
  print('');

  // Display complete WoT Thing description
  print('=== Complete WoT Thing Description ===\n');
  final thingDescription = device.asThingDescription();

  print('Device ID: ${thingDescription['id']}');
  print('Device name: ${thingDescription['title']}');
  print('Device type: ${thingDescription['@type']}');
  print('Device description: ${thingDescription['description']}');
  print('');

  print('Property list:');
  final properties = thingDescription['properties'] as Map<String, dynamic>;
  properties.forEach((name, desc) {
    print('  $name: ${desc['type']} ${desc['enum'] != null ? '(enum)' : ''}');
  });

  print('\n=== Enum Value Validation Demo ===\n');

  // Test valid enum values
  print('Testing valid enum values:');
  for (final mode in OperationMode.values) {
    print('  Setting mode to: $mode');
    operationModeProperty.setValue(mode.toString());
    print('  Current mode: ${operationModeProperty.getValue()}');
  }

  // Test invalid enum values (this will be handled in business logic)
  print('\nTesting invalid enum values:');
  try {
    final invalidMode = 'invalid_mode';
    print('  Attempting to set invalid mode: $invalidMode');

    // This won't fail directly, but will be handled in business logic
    operationModeProperty.setValue(invalidMode);

    // In actual listener, validation and error handling would occur
    try {
      OperationMode.fromString(invalidMode);
    } catch (e) {
      print('  Caught error: $e');
      print('  Reverting to previous valid value');
      operationModeProperty.setValue(OperationMode.automatic.toString());
    }
  } catch (e) {
    print('  Handling error: $e');
  }

  print('\n=== Summary ===\n');
  print('Key points for using Dart enum as properties in lw_wot:');
  print('');
  print('1. Define enum with toString() and fromString() methods');
  print('2. Set enumValues list in WotPropertyMetadata');
  print('3. Use string-type WotProperty to store enum values');
  print('4. Perform enum value validation and business logic in property listeners');
  print('5. Distinguish between read-only and writable enum properties for different scenarios');
  print('6. In WoT description, enum information is automatically included in property descriptions');
}
