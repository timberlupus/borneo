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

    test('创建包含枚举值的属性', () {
      // 创建一个带枚举约束的字符串属性
      final operationModeProperty = WotProperty<String>(
        thing,
        'operationMode',
        WotValue<String>(DeviceOperationMode.idle.toString()),
        WotPropertyMetadata(
          type: 'string',
          title: 'Operation Mode',
          description: 'Current operation mode of the device',
          enumValues: DeviceOperationMode.allStringValues,
          readOnly: false,
        ),
      );

      thing.addProperty(operationModeProperty);

      // 验证属性创建
      expect(operationModeProperty.getName(), equals('operationMode'));
      expect(operationModeProperty.getValue(), equals('idle'));
      expect(operationModeProperty.getMetadata().enumValues, equals(['idle', 'active', 'maintenance', 'error']));
      expect(operationModeProperty.getMetadata().readOnly, isFalse);
    });

    test('设置和获取枚举属性值', () {
      final priorityProperty = WotProperty<String>(
        thing,
        'priority',
        WotValue<String>(Priority.medium.toString()),
        WotPropertyMetadata(
          type: 'string',
          title: 'Priority Level',
          description: 'Priority level for device operations',
          enumValues: Priority.allStringValues,
          readOnly: false,
        ),
      );

      thing.addProperty(priorityProperty);

      // 测试设置有效的枚举值
      priorityProperty.setValue(Priority.high.toString());
      expect(priorityProperty.getValue(), equals('high'));

      priorityProperty.setValue(Priority.critical.toString());
      expect(priorityProperty.getValue(), equals('critical'));

      // 验证枚举值列表
      expect(priorityProperty.getMetadata().enumValues, containsAll(['low', 'medium', 'high', 'critical']));
    });

    test('属性描述包含枚举信息', () {
      final modeProperty = WotProperty<String>(
        thing,
        'deviceMode',
        WotValue<String>(DeviceOperationMode.active.toString()),
        WotPropertyMetadata(
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

    test('只读枚举属性', () {
      final statusProperty = WotProperty<String>(
        thing,
        'connectionStatus',
        WotValue<String>('connected'),
        WotPropertyMetadata(
          type: 'string',
          title: 'Connection Status',
          description: 'Current connection status',
          enumValues: ['connected', 'disconnected', 'connecting', 'error'],
          readOnly: true,
        ),
      );

      thing.addProperty(statusProperty);

      // 验证只读属性
      expect(statusProperty.getMetadata().readOnly, isTrue);

      // 尝试设置只读属性应该抛出异常
      expect(() => statusProperty.setValue('disconnected'), throwsA(isA<Exception>()));
    });

    test('枚举属性在 Thing 描述中的表示', () {
      // 添加多个枚举属性
      final operationModeProperty = WotProperty<String>(
        thing,
        'operationMode',
        WotValue<String>(DeviceOperationMode.idle.toString()),
        WotPropertyMetadata(
          type: 'string',
          title: 'Operation Mode',
          enumValues: DeviceOperationMode.allStringValues,
          readOnly: false,
        ),
      );

      final priorityProperty = WotProperty<String>(
        thing,
        'priority',
        WotValue<String>(Priority.low.toString()),
        WotPropertyMetadata(type: 'string', title: 'Priority', enumValues: Priority.allStringValues, readOnly: false),
      );

      thing.addProperty(operationModeProperty);
      thing.addProperty(priorityProperty);

      final thingDescription = thing.asThingDescription();

      // 验证 Thing 描述包含属性
      expect(thingDescription['properties'], contains('operationMode'));
      expect(thingDescription['properties'], contains('priority'));

      // 验证属性描述中包含枚举信息
      final operationModeDesc = thingDescription['properties']['operationMode'];
      expect(operationModeDesc['enum'], equals(['idle', 'active', 'maintenance', 'error']));

      final priorityDesc = thingDescription['properties']['priority'];
      expect(priorityDesc['enum'], equals(['low', 'medium', 'high', 'critical']));
    });
    test('枚举属性值变化监听', () async {
      var valueChangeCount = 0;
      String? lastValue;

      final modeProperty = WotProperty<String>(
        thing,
        'testMode',
        WotValue<String>(DeviceOperationMode.idle.toString()),
        WotPropertyMetadata(
          type: 'string',
          title: 'Test Mode',
          enumValues: DeviceOperationMode.allStringValues,
          readOnly: false,
        ),
      );

      thing.addProperty(modeProperty);

      // 监听值变化
      modeProperty.value.onUpdate.listen((newValue) {
        valueChangeCount++;
        lastValue = newValue;
      });

      // 改变值
      modeProperty.setValue(DeviceOperationMode.active.toString());

      // 等待异步事件处理
      await Future.delayed(Duration(milliseconds: 10));

      expect(valueChangeCount, greaterThan(0));
      expect(lastValue, equals('active'));

      // 再次改变值
      modeProperty.setValue(DeviceOperationMode.maintenance.toString());
      await Future.delayed(Duration(milliseconds: 10));
      expect(lastValue, equals('maintenance'));
    });

    test('复杂的枚举属性使用场景', () {
      // 创建一个模拟智能恒温器的设备
      final thermostat = WotThing('thermostat-001', 'Smart Thermostat', [
        'Thermostat',
      ], 'A smart thermostat with multiple enum properties');

      // 工作模式枚举属性
      final workModeProperty = WotProperty<String>(
        thermostat,
        'workMode',
        WotValue<String>('auto'),
        WotPropertyMetadata(
          type: 'string',
          title: 'Work Mode',
          description: 'Thermostat working mode',
          enumValues: ['auto', 'manual', 'schedule', 'vacation'],
          readOnly: false,
        ),
      );

      // 风扇速度枚举属性
      final fanSpeedProperty = WotProperty<String>(
        thermostat,
        'fanSpeed',
        WotValue<String>('medium'),
        WotPropertyMetadata(
          type: 'string',
          title: 'Fan Speed',
          description: 'Fan speed setting',
          enumValues: ['low', 'medium', 'high', 'auto'],
          readOnly: false,
        ),
      );

      // 系统状态只读枚举属性
      final systemStatusProperty = WotProperty<String>(
        thermostat,
        'systemStatus',
        WotValue<String>('idle'),
        WotPropertyMetadata(
          type: 'string',
          title: 'System Status',
          description: 'Current system status',
          enumValues: ['idle', 'heating', 'cooling', 'fan_only'],
          readOnly: true,
        ),
      );

      // 目标温度数值属性作为对比
      final targetTempProperty = WotProperty<double>(
        thermostat,
        'targetTemperature',
        WotValue<double>(22.0),
        WotPropertyMetadata(
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

      // 验证所有属性都已添加
      expect(thermostat.getProperty('workMode'), isNotNull);
      expect(thermostat.getProperty('fanSpeed'), isNotNull);
      expect(thermostat.getProperty('systemStatus'), isNotNull);
      expect(thermostat.getProperty('targetTemperature'), isNotNull);

      // 验证枚举属性的约束
      expect(workModeProperty.getMetadata().enumValues, equals(['auto', 'manual', 'schedule', 'vacation']));
      expect(fanSpeedProperty.getMetadata().enumValues, equals(['low', 'medium', 'high', 'auto']));

      // 验证数值属性的约束
      expect(targetTempProperty.getMetadata().minimum, equals(10));
      expect(targetTempProperty.getMetadata().maximum, equals(35));
      expect(targetTempProperty.getMetadata().unit, equals('°C'));

      // 测试属性值设置
      workModeProperty.setValue('manual');
      fanSpeedProperty.setValue('high');
      targetTempProperty.setValue(24.5);

      expect(workModeProperty.getValue(), equals('manual'));
      expect(fanSpeedProperty.getValue(), equals('high'));
      expect(targetTempProperty.getValue(), equals(24.5));

      // 验证 Thing 描述的完整性
      final description = thermostat.asThingDescription();
      expect(description['properties'], hasLength(4));
      expect(description['@type'], contains('Thermostat'));
    });
  });
}
