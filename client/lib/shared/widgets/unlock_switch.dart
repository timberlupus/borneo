import 'package:flutter/material.dart';

class UnlockSwitch extends Switch {
  const UnlockSwitch({super.key, required super.value, required super.onChanged});

  @override
  Widget build(BuildContext context) => Switch(
    value: super.value,
    onChanged: super.onChanged,
    thumbIcon: WidgetStateProperty.resolveWith<Icon?>((Set<WidgetState> states) {
      if (states.contains(WidgetState.selected)) {
        return Icon(Icons.lock_open_outlined, size: 16, color: Theme.of(context).primaryColor);
      }
      return Icon(Icons.lock_outline, size: 16, color: Colors.white);
    }),
  );
}
