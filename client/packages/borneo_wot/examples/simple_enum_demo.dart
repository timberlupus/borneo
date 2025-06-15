// simple_enum_demo.dart
// 在 borneo_wot 中使用 Dart enum 的简单演示

import 'package:borneo_wot/property.dart';
import 'package:borneo_wot/thing.dart';
import 'package:borneo_wot/value.dart';

// 定义设备状态枚举
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

// 定义操作模式枚举
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
  print('=== 在 borneo_wot 中使用 Dart Enum 属性的示例 ===\n');

  // 创建 WoT Thing
  final device = WotThing('smart-device-001', 'Smart Device Controller', [
    'SmartDevice',
    'Controller',
  ], 'A smart device demonstrating enum properties');

  // 1. 创建设备状态枚举属性（只读）
  final deviceStateProperty = WotProperty<String>(
    device,
    'deviceState',
    WotValue<String>(DeviceState.standby.toString()),
    WotPropertyMetadata(
      type: 'string',
      title: 'Device State',
      description: 'Current state of the device',
      enumValues: DeviceState.allValues, // ['offline', 'standby', 'active', 'maintenance']
      readOnly: true, // 只读，通常由设备内部状态决定
    ),
  );

  // 2. 创建操作模式枚举属性（可读写）
  final operationModeProperty = WotProperty<String>(
    device,
    'operationMode',
    WotValue<String>(OperationMode.automatic.toString()),
    WotPropertyMetadata(
      type: 'string',
      title: 'Operation Mode',
      description: 'How the device operates',
      enumValues: OperationMode.allValues, // ['manual', 'automatic', 'scheduled']
      readOnly: false, // 可写，用户可以更改
    ),
  );

  // 3. 创建其他类型的属性作为对比
  final temperatureProperty = WotProperty<double>(
    device,
    'temperature',
    WotValue<double>(22.5),
    WotPropertyMetadata(
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
    device,
    'enabled',
    WotValue<bool>(true),
    WotPropertyMetadata(
      type: 'boolean',
      title: 'Enabled',
      description: 'Whether the device is enabled',
      readOnly: false,
    ),
  );

  // 添加属性到设备
  device.addProperty(deviceStateProperty);
  device.addProperty(operationModeProperty);
  device.addProperty(temperatureProperty);
  device.addProperty(enabledProperty);

  print('设备创建完成，包含以下属性:');
  print('- deviceState (enum): ${deviceStateProperty.getValue()}');
  print('- operationMode (enum): ${operationModeProperty.getValue()}');
  print('- temperature (number): ${temperatureProperty.getValue()}°C');
  print('- enabled (boolean): ${enabledProperty.getValue()}');
  print('');

  // 演示枚举属性的使用
  print('=== 演示枚举属性操作 ===\n');

  // 监听属性变化
  operationModeProperty.value.onUpdate.listen((newMode) {
    print('操作模式已更改为: $newMode');

    // 根据模式执行不同的业务逻辑
    final mode = OperationMode.fromString(newMode);
    switch (mode) {
      case OperationMode.manual:
        print('  -> 切换到手动模式，等待用户指令');
        break;
      case OperationMode.automatic:
        print('  -> 切换到自动模式，开始自动运行');
        break;
      case OperationMode.scheduled:
        print('  -> 切换到定时模式，按计划执行任务');
        break;
    }
  });

  // 测试更改枚举值
  print('1. 当前操作模式: ${operationModeProperty.getValue()}');

  print('2. 更改为手动模式...');
  operationModeProperty.setValue(OperationMode.manual.toString());

  print('3. 更改为定时模式...');
  operationModeProperty.setValue(OperationMode.scheduled.toString());

  // 模拟设备状态变化（只读属性，只能内部更改）
  print('\n4. 模拟设备状态变化...');
  print('当前设备状态: ${deviceStateProperty.getValue()}');

  // 通过内部逻辑更改状态
  deviceStateProperty.value.set(DeviceState.active.toString());
  print('设备状态更新为: ${deviceStateProperty.getValue()}');

  // 显示属性描述信息
  print('\n=== 属性描述信息 ===\n');

  final deviceStateDesc = deviceStateProperty.asPropertyDescription();
  print('设备状态属性:');
  print('  类型: ${deviceStateDesc['type']}');
  print('  枚举值: ${deviceStateDesc['enum']}');
  print('  只读: ${deviceStateDesc['readOnly']}');
  print('  标题: ${deviceStateDesc['title']}');
  print('');

  final operationModeDesc = operationModeProperty.asPropertyDescription();
  print('操作模式属性:');
  print('  类型: ${operationModeDesc['type']}');
  print('  枚举值: ${operationModeDesc['enum']}');
  print('  只读: ${operationModeDesc['readOnly']}');
  print('  标题: ${operationModeDesc['title']}');
  print('');

  // 显示完整的 WoT Thing 描述
  print('=== 完整的 WoT Thing 描述 ===\n');
  final thingDescription = device.asThingDescription();

  print('设备 ID: ${thingDescription['id']}');
  print('设备名称: ${thingDescription['title']}');
  print('设备类型: ${thingDescription['@type']}');
  print('设备描述: ${thingDescription['description']}');
  print('');

  print('属性列表:');
  final properties = thingDescription['properties'] as Map<String, dynamic>;
  properties.forEach((name, desc) {
    print('  $name: ${desc['type']} ${desc['enum'] != null ? '(enum)' : ''}');
  });

  print('\n=== 枚举值验证演示 ===\n');

  // 测试有效的枚举值
  print('测试有效的枚举值:');
  for (final mode in OperationMode.values) {
    print('  设置模式为: $mode');
    operationModeProperty.setValue(mode.toString());
    print('  当前模式: ${operationModeProperty.getValue()}');
  }

  // 测试无效的枚举值（这会在业务逻辑中处理）
  print('\n测试无效的枚举值:');
  try {
    final invalidMode = 'invalid_mode';
    print('  尝试设置无效模式: $invalidMode');

    // 这不会直接失败，但在业务逻辑中会处理
    operationModeProperty.setValue(invalidMode);

    // 在实际的监听器中会验证并处理错误
    try {
      OperationMode.fromString(invalidMode);
    } catch (e) {
      print('  捕获到错误: $e');
      print('  恢复到上一个有效值');
      operationModeProperty.setValue(OperationMode.automatic.toString());
    }
  } catch (e) {
    print('  处理错误: $e');
  }

  print('\n=== 总结 ===\n');
  print('在 borneo_wot 中使用 Dart enum 作为属性的要点:');
  print('');
  print('1. 定义枚举时提供 toString() 和 fromString() 方法');
  print('2. 在 WotPropertyMetadata 中设置 enumValues 列表');
  print('3. 使用字符串类型的 WotProperty 存储枚举值');
  print('4. 在属性监听器中进行枚举值验证和业务逻辑处理');
  print('5. 区分只读和可写的枚举属性用于不同场景');
  print('6. 在 WoT 描述中，enum 信息会自动包含在属性描述里');
}
