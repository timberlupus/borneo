// enum_property_borneo_wot_example.dart
// 展示如何在 borneo_wot 项目中使用 Dart enum 作为属性

import 'package:borneo_wot/property.dart';
import 'package:borneo_wot/thing.dart';
import 'package:borneo_wot/value.dart';

/// 设备运行模式枚举
enum DeviceMode {
  /// 关闭状态
  off,

  /// 开启状态
  on,

  /// 待机状态
  standby,

  /// 维护模式
  maintenance;

  @override
  String toString() => name;

  /// 从字符串创建枚举值
  static DeviceMode fromString(String value) {
    return DeviceMode.values.firstWhere(
      (e) => e.name == value,
      orElse: () => throw ArgumentError('Unknown DeviceMode: $value'),
    );
  }

  /// 获取所有可能的字符串值
  static List<String> get allValues => values.map((e) => e.name).toList();

  /// 业务逻辑：是否处于活跃状态
  bool get isActive => this == on;

  /// 业务逻辑：是否可以执行操作
  bool get canOperate => this == on || this == standby;
}

/// 优先级枚举
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

  static List<String> get allValues => values.map((e) => e.name).toList();

  /// 获取优先级数值（用于排序）
  int get level => index;
}

void main() {
  print('=== borneo_wot 中的 Dart Enum 属性示例 ===\n');

  // 1. 创建 WoT Thing
  final smartDevice = WotThing('smart-controller-001', 'Smart Controller', [
    'SmartDevice',
    'Controller',
  ], 'A smart device controller demonstrating enum properties in borneo_wot');

  // 2. 创建设备模式枚举属性（可读写）
  final deviceModeProperty = WotProperty<String>(
    smartDevice,
    'deviceMode',
    WotValue<String>(DeviceMode.standby.toString()),
    WotPropertyMetadata(
      type: 'string',
      title: 'Device Mode',
      description: 'Current operating mode of the smart device',
      enumValues: DeviceMode.allValues, // ['off', 'on', 'standby', 'maintenance']
      readOnly: false, // 用户可以更改
    ),
  );

  // 3. 创建优先级枚举属性（可读写）
  final priorityProperty = WotProperty<String>(
    smartDevice,
    'priority',
    WotValue<String>(Priority.medium.toString()),
    WotPropertyMetadata(
      type: 'string',
      title: 'Priority Level',
      description: 'Priority level for device operations',
      enumValues: Priority.allValues, // ['low', 'medium', 'high', 'critical']
      readOnly: false,
    ),
  );

  // 4. 创建其他类型的属性用于对比
  final temperatureProperty = WotProperty<double>(
    smartDevice,
    'temperature',
    WotValue<double>(25.0),
    WotPropertyMetadata(
      type: 'number',
      title: 'Temperature',
      description: 'Current temperature reading',
      unit: '°C',
      minimum: -40,
      maximum: 100,
      readOnly: true, // 只读传感器数据
    ),
  );

  final enabledProperty = WotProperty<bool>(
    smartDevice,
    'enabled',
    WotValue<bool>(true),
    WotPropertyMetadata(
      type: 'boolean',
      title: 'Enabled',
      description: 'Whether the device is enabled',
      readOnly: false,
    ),
  );

  // 5. 将属性添加到设备
  smartDevice.addProperty(deviceModeProperty);
  smartDevice.addProperty(priorityProperty);
  smartDevice.addProperty(temperatureProperty);
  smartDevice.addProperty(enabledProperty);

  print('设备创建完成！初始状态:');
  printDeviceState(smartDevice);
  print('');

  // 6. 演示枚举属性的使用
  demonstrateEnumProperties(smartDevice, deviceModeProperty, priorityProperty);

  // 7. 显示 WoT 属性描述
  showPropertyDescriptions(smartDevice);

  // 8. 显示完整的 Thing 描述
  showThingDescription(smartDevice);

  print('\n=== 示例完成 ===');
  print('关键要点:');
  print('1. 使用 enumValues 在元数据中定义枚举约束');
  print('2. 枚举值以字符串形式存储在 WotProperty<String> 中');
  print('3. 提供 fromString() 和 toString() 方法进行转换');
  print('4. 在 WoT 描述中，enum 信息会自动包含');
  print('5. 可以在枚举中添加业务逻辑方法');
}

/// 打印设备当前状态
void printDeviceState(WotThing device) {
  final mode = device.getProperty('deviceMode')?.getValue();
  final priority = device.getProperty('priority')?.getValue();
  final temp = device.getProperty('temperature')?.getValue();
  final enabled = device.getProperty('enabled')?.getValue();

  print('  设备模式: $mode');
  print('  优先级: $priority');
  print('  温度: ${temp}°C');
  print('  启用状态: $enabled');
}

/// 演示枚举属性的操作
void demonstrateEnumProperties(
  WotThing device,
  WotProperty<String> modeProperty,
  WotProperty<String> priorityProperty,
) {
  print('=== 演示枚举属性操作 ===\n');

  // 监听属性变化
  modeProperty.value.onUpdate.listen((newMode) {
    print('📢 设备模式已更改为: $newMode');

    // 根据新模式执行业务逻辑
    try {
      final mode = DeviceMode.fromString(newMode);
      switch (mode) {
        case DeviceMode.off:
          print('   🔴 设备已关闭');
          break;
        case DeviceMode.on:
          print('   🟢 设备已开启，正常运行');
          break;
        case DeviceMode.standby:
          print('   🟡 设备进入待机模式');
          break;
        case DeviceMode.maintenance:
          print('   🔧 设备进入维护模式');
          break;
      }

      if (mode.canOperate) {
        print('   ✅ 设备可以执行操作');
      } else {
        print('   ❌ 设备当前无法执行操作');
      }
    } catch (e) {
      print('   ❌ 无效的设备模式: $e');
    }
  });

  priorityProperty.value.onUpdate.listen((newPriority) {
    print('📢 优先级已更改为: $newPriority');

    try {
      final priority = Priority.fromString(newPriority);
      print('   🎯 优先级等级: ${priority.level}');

      if (priority == Priority.critical) {
        print('   ⚠️  关键优先级！需要立即处理');
      }
    } catch (e) {
      print('   ❌ 无效的优先级: $e');
    }
  });

  // 测试设置不同的枚举值
  print('1. 测试设备模式变化:');
  for (final mode in DeviceMode.values) {
    print('   设置模式为: $mode');
    modeProperty.setValue(mode.toString());
    // 添加短暂延迟以便看到变化
    Future.delayed(Duration(milliseconds: 100));
  }

  print('\n2. 测试优先级变化:');
  for (final priority in Priority.values) {
    print('   设置优先级为: $priority');
    priorityProperty.setValue(priority.toString());
    Future.delayed(Duration(milliseconds: 100));
  }

  print('\n3. 当前最终状态:');
  printDeviceState(device);
  print('');
}

/// 显示属性描述信息
void showPropertyDescriptions(WotThing device) {
  print('=== WoT 属性描述 ===\n');

  final deviceModeProperty = device.getProperty('deviceMode');
  if (deviceModeProperty != null) {
    final desc = deviceModeProperty.asPropertyDescription();
    print('设备模式属性:');
    print('  类型: ${desc['type']}');
    print('  标题: ${desc['title']}');
    print('  描述: ${desc['description']}');
    print('  枚举值: ${desc['enum']}');
    print('  只读: ${desc['readOnly']}');
    print('  链接: ${desc['links']?.length ?? 0} 个');
    print('');
  }

  final priorityProperty = device.getProperty('priority');
  if (priorityProperty != null) {
    final desc = priorityProperty.asPropertyDescription();
    print('优先级属性:');
    print('  类型: ${desc['type']}');
    print('  标题: ${desc['title']}');
    print('  描述: ${desc['description']}');
    print('  枚举值: ${desc['enum']}');
    print('  只读: ${desc['readOnly']}');
    print('');
  }
}

/// 显示完整的 Thing 描述
void showThingDescription(WotThing device) {
  print('=== 完整的 WoT Thing 描述 ===\n');

  final description = device.asThingDescription();

  print('设备信息:');
  print('  ID: ${description['id']}');
  print('  标题: ${description['title']}');
  print('  类型: ${description['@type']}');
  print('  描述: ${description['description']}');
  print('');

  print('属性列表:');
  final properties = description['properties'] as Map<String, dynamic>;
  properties.forEach((name, propDesc) {
    final isEnum = propDesc['enum'] != null;
    final type = propDesc['type'];
    final readOnly = propDesc['readOnly'] ?? false;

    print('  $name:');
    print('    类型: $type ${isEnum ? '(枚举)' : ''}');
    print('    访问: ${readOnly ? '只读' : '可读写'}');

    if (isEnum) {
      print('    枚举值: ${propDesc['enum']}');
    }

    if (propDesc['unit'] != null) {
      print('    单位: ${propDesc['unit']}');
    }

    if (propDesc['minimum'] != null || propDesc['maximum'] != null) {
      print('    范围: ${propDesc['minimum']} - ${propDesc['maximum']}');
    }

    print('');
  });

  if (description['actions'] != null) {
    final actions = description['actions'] as Map<String, dynamic>;
    print('动作列表: ${actions.keys.toList()}');
  } else {
    print('动作列表: []');
  }

  if (description['events'] != null) {
    final events = description['events'] as Map<String, dynamic>;
    print('事件列表: ${events.keys.toList()}');
  } else {
    print('事件列表: []');
  }
}
