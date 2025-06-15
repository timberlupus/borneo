// 基于 borneo_wot 项目的 Dart enum 属性实现示例
// 参考现有的 LyfiState 和 LyfiMode 实现

import 'package:borneo_wot/property.dart';
import 'package:borneo_wot/thing.dart';
import 'package:borneo_wot/value.dart';

// 1. 定义设备工作模式枚举
enum DeviceWorkMode {
  auto, // 自动模式
  manual, // 手动模式
  scheduled, // 定时模式
  eco; // 节能模式

  // 将枚举转换为字符串，用于 WoT 属性值
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

  // 从字符串创建枚举值
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

  // 获取所有可能的字符串值
  static List<String> get allValues => values.map((e) => e.toString()).toList();
}

// 2. 定义设备状态枚举
enum DeviceHealthStatus {
  healthy, // 健康
  warning, // 警告
  critical, // 严重
  offline; // 离线

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

  // 添加业务逻辑方法
  bool get isOperational => this == healthy || this == warning;
  bool get needsAttention => this == warning || this == critical;
}

// 3. 创建使用枚举的 WoT 设备类
class SmartAirConditioner {
  late final WotThing _thing;

  // 设备状态
  DeviceWorkMode _workMode = DeviceWorkMode.auto;
  DeviceHealthStatus _healthStatus = DeviceHealthStatus.healthy;

  // WoT 属性
  late WotProperty<String> _workModeProperty;
  late WotProperty<String> _healthStatusProperty;
  late WotProperty<double> _temperatureProperty;
  late WotProperty<bool> _powerProperty;

  SmartAirConditioner(String id, String name) {
    _initializeThing(id, name);
  }

  void _initializeThing(String id, String name) {
    // 创建 WoT Thing
    _thing = WotThing(id, name, [
      'AirConditioner',
      'ClimateControl',
    ], 'Smart air conditioner with enum-based mode control');

    // 创建工作模式属性（可读写，枚举类型）
    _workModeProperty = WotProperty<String>(
      _thing,
      'workMode',
      WotValue<String>(_workMode.toString()),
      WotPropertyMetadata(
        type: 'string',
        title: 'Work Mode',
        description: 'Current working mode of the air conditioner',
        enumValues: DeviceWorkMode.allValues,
        readOnly: false,
      ),
    );

    // 创建健康状态属性（只读，枚举类型）
    _healthStatusProperty = WotProperty<String>(
      _thing,
      'healthStatus',
      WotValue<String>(_healthStatus.toString()),
      WotPropertyMetadata(
        type: 'string',
        title: 'Health Status',
        description: 'Current health status of the device',
        enumValues: DeviceHealthStatus.allValues,
        readOnly: true,
      ),
    );

    // 创建温度属性（数值类型）
    _temperatureProperty = WotProperty<double>(
      _thing,
      'targetTemperature',
      WotValue<double>(24.0),
      WotPropertyMetadata(
        type: 'number',
        title: 'Target Temperature',
        description: 'Target temperature setting',
        unit: '°C',
        minimum: 16,
        maximum: 30,
        readOnly: false,
      ),
    );

    // 创建电源属性（布尔类型）
    _powerProperty = WotProperty<bool>(
      _thing,
      'power',
      WotValue<bool>(false),
      WotPropertyMetadata(type: 'boolean', title: 'Power', description: 'Power on/off state', readOnly: false),
    );

    // 添加属性到 Thing
    _thing.addProperty(_workModeProperty);
    _thing.addProperty(_healthStatusProperty);
    _thing.addProperty(_temperatureProperty);
    _thing.addProperty(_powerProperty);

    // 监听属性变化
    _setupPropertyListeners();
  }

  void _setupPropertyListeners() {
    // 监听工作模式变化
    _workModeProperty.value.onUpdate.listen((newValue) {
      try {
        final newMode = DeviceWorkMode.fromString(newValue);
        _handleWorkModeChange(newMode);
      } catch (e) {
        print('Invalid work mode: $newValue');
        // 回滚到之前的值
        _workModeProperty.setValue(_workMode.toString());
      }
    });

    // 监听电源状态变化
    _powerProperty.value.onUpdate.listen((isPowerOn) {
      _handlePowerChange(isPowerOn);
    });

    // 监听目标温度变化
    _temperatureProperty.value.onUpdate.listen((temperature) {
      _handleTemperatureChange(temperature);
    });
  }

  void _handleWorkModeChange(DeviceWorkMode newMode) {
    if (_workMode == newMode) return;

    final oldMode = _workMode;
    print('Work mode changing from $oldMode to $newMode');

    // 检查是否可以切换模式
    if (!_healthStatus.isOperational) {
      print('Cannot change mode: device is not operational (status: $_healthStatus)');
      return;
    }

    _workMode = newMode;

    // 根据新模式执行相应逻辑
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
      // 关机时重置为自动模式
      _workMode = DeviceWorkMode.auto;
      _workModeProperty.setValue(_workMode.toString());
    }
  }

  void _handleTemperatureChange(double temperature) {
    print('Target temperature set to: ${temperature}°C');

    // 如果在自动模式下，可能需要切换到手动模式
    if (_workMode == DeviceWorkMode.auto) {
      print('Switching to manual mode due to temperature change');
      _workMode = DeviceWorkMode.manual;
      _workModeProperty.setValue(_workMode.toString());
    }
  }

  // 业务逻辑方法
  void _enableAutoMode() {
    print('Enabling automatic temperature control');
    // 实现自动模式逻辑
  }

  void _enableManualMode() {
    print('Enabling manual temperature control');
    // 实现手动模式逻辑
  }

  void _enableScheduledMode() {
    print('Enabling scheduled temperature control');
    // 实现定时模式逻辑
  }

  void _enableEcoMode() {
    print('Enabling eco-friendly mode');
    // 实现节能模式逻辑
    // 可能自动调整温度到更节能的设置
    if (_temperatureProperty.getValue() < 26) {
      _temperatureProperty.setValue(26.0);
    }
  }

  // 模拟设备健康状态变化
  void updateHealthStatus(DeviceHealthStatus newStatus) {
    if (_healthStatus == newStatus) return;

    final oldStatus = _healthStatus;
    _healthStatus = newStatus;
    _healthStatusProperty.setValue(_healthStatus.toString());

    print('Health status changed from $oldStatus to $newStatus');

    // 根据健康状态执行相应操作
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

  // 公共接口
  DeviceWorkMode get currentWorkMode => _workMode;
  DeviceHealthStatus get currentHealthStatus => _healthStatus;
  WotThing get thing => _thing;

  // 获取属性值
  bool get isPowerOn => _powerProperty.getValue();
  double get targetTemperature => _temperatureProperty.getValue();

  // 设置属性值
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

// 4. 使用示例
void demonstrateEnumProperties() {
  print('=== Smart Air Conditioner with Enum Properties ===\n');

  // 创建设备
  final aircon = SmartAirConditioner('ac-001', 'Living Room AC');

  // 打印初始状态
  print('Initial state:');
  print('  Work Mode: ${aircon.currentWorkMode}');
  print('  Health Status: ${aircon.currentHealthStatus}');
  print('  Power: ${aircon.isPowerOn}');
  print('  Target Temperature: ${aircon.targetTemperature}°C\n');

  // 开机
  print('Turning on the air conditioner...');
  aircon.setPower(true);
  print('');

  // 设置温度（这会触发模式切换到手动）
  print('Setting target temperature to 22°C...');
  aircon.setTargetTemperature(22.0);
  print('Current mode after temperature change: ${aircon.currentWorkMode}\n');

  // 切换到节能模式
  print('Switching to eco mode...');
  aircon.setWorkMode(DeviceWorkMode.eco);
  print('Temperature after eco mode: ${aircon.targetTemperature}°C\n');

  // 切换到定时模式
  print('Switching to scheduled mode...');
  aircon.setWorkMode(DeviceWorkMode.scheduled);
  print('');

  // 模拟设备健康状态变化
  print('Simulating device health changes...');
  aircon.updateHealthStatus(DeviceHealthStatus.warning);
  print('');

  // 尝试在警告状态下切换模式（应该成功）
  print('Trying to switch to manual mode during warning status...');
  aircon.setWorkMode(DeviceWorkMode.manual);
  print('');

  // 模拟严重故障
  print('Simulating critical device failure...');
  aircon.updateHealthStatus(DeviceHealthStatus.critical);
  print('Mode after critical failure: ${aircon.currentWorkMode}');
  print('Power after critical failure: ${aircon.isPowerOn}\n');

  // 显示 WoT 属性描述
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

// 5. 测试不同的枚举使用场景
void testEnumValidation() {
  print('=== Testing Enum Validation ===\n');

  final aircon = SmartAirConditioner('ac-test', 'Test AC');

  // 测试有效的枚举值
  print('Testing valid enum values:');
  for (final mode in DeviceWorkMode.values) {
    print('  Setting mode to: $mode');
    aircon.setWorkMode(mode);
    print('  Current mode: ${aircon.currentWorkMode}');
  }
  print('');

  // 测试无效的枚举值（通过直接设置字符串）
  print('Testing invalid enum value:');
  try {
    aircon.thing.getProperty('workMode')?.setValue('invalid_mode');
  } catch (e) {
    print('  Caught expected error: $e');
  }
  print('  Current mode remains: ${aircon.currentWorkMode}\n');
}

void main() {
  // 运行演示
  demonstrateEnumProperties();

  // 测试枚举验证
  testEnumValidation();

  print('=== Enum Property Example Complete ===');
}
