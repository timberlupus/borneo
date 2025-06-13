import 'package:borneo_kernel_abstractions/models/wot/property.dart';

class WotLyfiStateProperty extends WotEnumProperty {
  WotLyfiStateProperty({required super.value, super.description, super.valueForwarder})
    : super(name: "state", title: "State", readOnly: false, atType: "LyfiStateProperty", enumeration: []);
}

class WotLyfiModeProperty extends WotEnumProperty {
  WotLyfiModeProperty({required super.value, super.description, super.valueForwarder})
    : super(name: "mode", title: "Mode", readOnly: false, atType: "LyfiModeProperty", enumeration: []);
}
