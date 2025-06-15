import 'package:borneo_wot/property.dart';
import 'package:borneo_wot/thing.dart';
import 'package:borneo_wot/value.dart';

enum DeviceMode {
  off,
  on,
  standby;

  @override
  String toString() => name;

  static List<String> get allValues => values.map((e) => e.name).toList();
}

void main() {
  print('Enum Property Example for borneo_wot');

  // 创建设备
  final device = WotThing('test-device', 'Test Device', ['TestDevice'], 'A test device with enum property');

  // 创建枚举属性
  final modeProperty = WotProperty<String>(
    device,
    'mode',
    WotValue<String>(DeviceMode.off.toString()),
    WotPropertyMetadata(
      type: 'string',
      title: 'Device Mode',
      description: 'Current mode of the device',
      enumValues: DeviceMode.allValues,
      readOnly: false,
    ),
  );

  device.addProperty(modeProperty);

  print('Initial mode: ${modeProperty.getValue()}');
  print('Available modes: ${DeviceMode.allValues}');

  // 修改属性值
  modeProperty.setValue(DeviceMode.on.toString());
  print('Mode changed to: ${modeProperty.getValue()}');

  // 显示属性描述
  final desc = modeProperty.asPropertyDescription();
  print('Property description:');
  print('  Type: ${desc['type']}');
  print('  Enum values: ${desc['enum']}');
  print('  Read only: ${desc['readOnly']}');

  print('Enum property example completed successfully!');
}
