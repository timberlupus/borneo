import 'package:flutter/material.dart';

class PowerSwitch extends Switch {
  const PowerSwitch(
      {super.key, required super.value, required super.onChanged});

  @override
  Widget build(BuildContext context) => Switch(
        value: super.value,
        onChanged: super.onChanged,
        thumbIcon:
            WidgetStateProperty.resolveWith<Icon?>((Set<WidgetState> states) {
          if (states.contains(WidgetState.selected)) {
            return Icon(Icons.power_settings_new_outlined,
                size: 16, color: Colors.white);
          } else {
            return Icon(Icons.power_settings_new_outlined,
                size: 16, color: Colors.white);
          }
        }),
      );
}
