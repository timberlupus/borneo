import 'package:borneo_wot/property.dart';
import 'package:borneo_wot/thing.dart';
import 'package:borneo_wot/value.dart';

enum DeviceWorkMode {
  auto,
  manual,
  scheduled,
  eco;

  @override
  String toString() {
    switch (this) {
      case DeviceWorkMode.auto:
        return 'auto';
      case DeviceWorkMode.manual:
        return 'manual';
      case DeviceWorkMode.scheduled:
        return 'scheduled';
      case DeviceWorkMode.eco:
        return 'eco';
    }
  }

  static DeviceWorkMode fromString(String value) {
    switch (value) {
      case 'auto':
        return DeviceWorkMode.auto;
      case 'manual':
        return DeviceWorkMode.manual;
      case 'scheduled':
        return DeviceWorkMode.scheduled;
      case 'eco':
        return DeviceWorkMode.eco;
      default:
        throw ArgumentError('Unknown DeviceWorkMode: $value');
    }
  }

  static List<String> get allValues => values.map((e) => e.toString()).toList();
}

enum DeviceHealthStatus {
  healthy,
  warning,
  critical,
  offline;

  @override
  String toString() {
    switch (this) {
      case DeviceHealthStatus.healthy:
        return 'healthy';
      case DeviceHealthStatus.warning:
        return 'warning';
      case DeviceHealthStatus.critical:
        return 'critical';
      case DeviceHealthStatus.offline:
        return 'offline';
    }
  }

  static DeviceHealthStatus fromString(String value) {
    switch (value) {
      case 'healthy':
        return DeviceHealthStatus.healthy;
      case 'warning':
        return DeviceHealthStatus.warning;
      case 'critical':
        return DeviceHealthStatus.critical;
      case 'offline':
        return DeviceHealthStatus.offline;
      default:
        throw ArgumentError('Unknown DeviceHealthStatus: $value');
    }
  }

  static List<String> get allValues => values.map((e) => e.toString()).toList();

  bool get isOperational => this == healthy || this == warning;
  bool get needsAttention => this == warning || this == critical;
}

class SmartAirConditioner {
  late final WotThing _thing;

  DeviceWorkMode _workMode = DeviceWorkMode.auto;
  DeviceHealthStatus _healthStatus = DeviceHealthStatus.healthy;

  late WotProperty<String> _workModeProperty;
  late WotProperty<String> _healthStatusProperty;
  late WotProperty<double> _temperatureProperty;
  late WotProperty<bool> _powerProperty;

  SmartAirConditioner(String id, String name) {
    _initializeThing(id, name);
  }

  void _initializeThing(String id, String name) {
    _thing = WotThing(
      id: id,
      title: name,
      type: ['AirConditioner', 'ClimateControl'],
      description: 'Smart air conditioner with enum-based mode control',
    );

    _workModeProperty = WotProperty<String>(
      thing: _thing,
      name: 'workMode',
      value: WotValue<String>(initialValue: _workMode.toString()),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Work Mode',
        description: 'Current working mode of the air conditioner',
        enumValues: DeviceWorkMode.allValues,
        readOnly: false,
      ),
    );

    _healthStatusProperty = WotProperty<String>(
      thing: _thing,
      name: 'healthStatus',
      value: WotValue<String>(initialValue: _healthStatus.toString()),
      metadata: WotPropertyMetadata(
        type: 'string',
        title: 'Health Status',
        description: 'Current health status of the device',
        enumValues: DeviceHealthStatus.allValues,
        readOnly: true,
      ),
    );

    _temperatureProperty = WotProperty<double>(
      thing: _thing,
      name: 'targetTemperature',
      value: WotValue<double>(initialValue: 24.0),
      metadata: WotPropertyMetadata(
        type: 'number',
        title: 'Target Temperature',
        description: 'Target temperature setting',
        unit: '°C',
        minimum: 16,
        maximum: 30,
        readOnly: false,
      ),
    );

    _powerProperty = WotProperty<bool>(
      thing: _thing,
      name: 'power',
      value: WotValue<bool>(initialValue: false),
      metadata: WotPropertyMetadata(
        type: 'boolean',
        title: 'Power',
        description: 'Power on/off state',
        readOnly: false,
      ),
    );

    _thing.addProperty(_workModeProperty);
    _thing.addProperty(_healthStatusProperty);
    _thing.addProperty(_temperatureProperty);
    _thing.addProperty(_powerProperty);

    _setupPropertyListeners();
  }

  void _setupPropertyListeners() {
    _workModeProperty.value.onUpdate.listen((newValue) {
      try {
        final newMode = DeviceWorkMode.fromString(newValue);
        _handleWorkModeChange(newMode);
      } catch (e) {
        print('Invalid work mode: $newValue');
        _workModeProperty.setValue(_workMode.toString());
      }
    });

    _powerProperty.value.onUpdate.listen((isPowerOn) {
      _handlePowerChange(isPowerOn);
    });

    _temperatureProperty.value.onUpdate.listen((temperature) {
      _handleTemperatureChange(temperature);
    });
  }

  void _handleWorkModeChange(DeviceWorkMode newMode) {
    if (_workMode == newMode) return;

    final oldMode = _workMode;
    print('Work mode changing from $oldMode to $newMode');

    if (!_healthStatus.isOperational) {
      print('Cannot change mode: device is not operational (status: $_healthStatus)');
      return;
    }

    _workMode = newMode;

    switch (newMode) {
      case DeviceWorkMode.auto:
        _enableAutoMode();
        break;
      case DeviceWorkMode.manual:
        _enableManualMode();
        break;
      case DeviceWorkMode.scheduled:
        _enableScheduledMode();
        break;
      case DeviceWorkMode.eco:
        _enableEcoMode();
        break;
    }

    print('Work mode changed to: $newMode');
  }

  void _handlePowerChange(bool isPowerOn) {
    print('Power ${isPowerOn ? 'ON' : 'OFF'}');

    if (!isPowerOn) {
      _workMode = DeviceWorkMode.auto;
      _workModeProperty.setValue(_workMode.toString());
    }
  }

  void _handleTemperatureChange(double temperature) {
    print('Target temperature set to: ${temperature}°C');

    if (_workMode == DeviceWorkMode.auto) {
      print('Switching to manual mode due to temperature change');
      _workMode = DeviceWorkMode.manual;
      _workModeProperty.setValue(_workMode.toString());
    }
  }

  void _enableAutoMode() {
    print('Enabling automatic temperature control');
  }

  void _enableManualMode() {
    print('Enabling manual temperature control');
  }

  void _enableScheduledMode() {
    print('Enabling scheduled temperature control');
  }

  void _enableEcoMode() {
    print('Enabling eco-friendly mode');
    if (_temperatureProperty.getValue() < 26) {
      _temperatureProperty.setValue(26.0);
    }
  }

  void updateHealthStatus(DeviceHealthStatus newStatus) {
    if (_healthStatus == newStatus) return;

    final oldStatus = _healthStatus;
    _healthStatus = newStatus;
    _healthStatusProperty.setValue(_healthStatus.toString());

    print('Health status changed from $oldStatus to $newStatus');

    if (newStatus == DeviceHealthStatus.critical) {
      print('CRITICAL: Device entering safe mode');
      _workMode = DeviceWorkMode.auto;
      _workModeProperty.setValue(_workMode.toString());
      _powerProperty.setValue(false);
    } else if (newStatus == DeviceHealthStatus.offline) {
      print('Device went offline');
      _powerProperty.setValue(false);
    }
  }

  DeviceWorkMode get currentWorkMode => _workMode;
  DeviceHealthStatus get currentHealthStatus => _healthStatus;
  WotThing get thing => _thing;

  bool get isPowerOn => _powerProperty.getValue();
  double get targetTemperature => _temperatureProperty.getValue();

  void setWorkMode(DeviceWorkMode mode) {
    _workModeProperty.setValue(mode.toString());
  }

  void setPower(bool on) {
    _powerProperty.setValue(on);
  }

  void setTargetTemperature(double temperature) {
    _temperatureProperty.setValue(temperature);
  }
}

void demonstrateEnumProperties() {
  print('=== Smart Air Conditioner with Enum Properties ===\n');

  final aircon = SmartAirConditioner('ac-001', 'Living Room AC');

  print('Initial state:');
  print('  Work Mode: ${aircon.currentWorkMode}');
  print('  Health Status: ${aircon.currentHealthStatus}');
  print('  Power: ${aircon.isPowerOn}');
  print('  Target Temperature: ${aircon.targetTemperature}°C\n');

  print('Turning on the air conditioner...');
  aircon.setPower(true);
  print('');

  print('Setting target temperature to 22°C...');
  aircon.setTargetTemperature(22.0);
  print('Current mode after temperature change: ${aircon.currentWorkMode}\n');

  print('Switching to eco mode...');
  aircon.setWorkMode(DeviceWorkMode.eco);
  print('Temperature after eco mode: ${aircon.targetTemperature}°C\n');

  print('Switching to scheduled mode...');
  aircon.setWorkMode(DeviceWorkMode.scheduled);
  print('');

  print('Simulating device health changes...');
  aircon.updateHealthStatus(DeviceHealthStatus.warning);
  print('');

  print('Trying to switch to manual mode during warning status...');

  print('Mode after critical failure: ${aircon.currentWorkMode}');
  print('Power after critical failure: ${aircon.isPowerOn}\n');

  print('=== WoT Property Descriptions ===');
  final workModeDesc = aircon.thing.getProperty('workMode')?.asPropertyDescription();
  print('Work Mode Property:');
  print('  Type: ${workModeDesc?['type']}');
  print('  Enum Values: ${workModeDesc?['enum']}');
  print('  Read Only: ${workModeDesc?['readOnly']}\n');

  final healthDesc = aircon.thing.getProperty('healthStatus')?.asPropertyDescription();
  print('Health Status Property:');
  print('  Type: ${healthDesc?['type']}');
  print('  Enum Values: ${healthDesc?['enum']}');
  print('  Read Only: ${healthDesc?['readOnly']}\n');
}

void testEnumValidation() {
  print('=== Testing Enum Validation ===\n');

  final aircon = SmartAirConditioner('ac-test', 'Test AC');

  print('Testing valid enum values:');
  for (final mode in DeviceWorkMode.values) {
    print('  Setting mode to: $mode');
    aircon.setWorkMode(mode);
    print('  Current mode: ${aircon.currentWorkMode}');
  }
  print('');

  print('Testing invalid enum value:');
  try {
    aircon.thing.getProperty('workMode')?.setValue('invalid_mode');
  } catch (e) {
    print('  Caught expected error: $e');
  }
  print('  Current mode remains: ${aircon.currentWorkMode}\n');
}

void main() {
  demonstrateEnumProperties();

  testEnumValidation();

  print('=== Enum Property Example Complete ===');
}
