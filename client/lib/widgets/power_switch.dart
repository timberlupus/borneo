import 'package:flutter/material.dart';

class PowerButton extends StatefulWidget {
  final bool value; // 绑定的开关状态
  final void Function(bool)? onChanged; // 状态变化回调
  final Widget label;

  const PowerButton({required this.value, required this.label, this.onChanged});

  @override
  _PowerButtonState createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  bool _isLoading = false; // 加载状态

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    // 根据状态设置颜色
    final iconColor = widget.value ? colorScheme.primary : colorScheme.error;
    final textColor = widget.value ? colorScheme.primary : colorScheme.error;
    final loadingColor = colorScheme.onSurface;

    return InkWell(
      onTap: _isLoading || widget.onChanged == null ? null : () => widget.onChanged?.call(widget.value), // 加载或无回调时禁用点击
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child:
                _isLoading
                    ? CircularProgressIndicator(color: loadingColor, key: ValueKey('loading'))
                    : Icon(
                      widget.value ? Icons.power_settings_new_outlined : Icons.power_settings_new,
                      key: ValueKey<bool>(widget.value),
                      size: 48,
                      color: iconColor,
                    ),
          ),
          AnimatedSwitcher(
            duration: Duration(milliseconds: 300),
            child:
                _isLoading
                    ? SizedBox.shrink(key: ValueKey('loading_text'))
                    : Text(
                      widget.value ? 'ON' : 'OFF',
                      key: ValueKey<bool>(widget.value),
                      style: textTheme.labelLarge?.copyWith(color: textColor, fontWeight: FontWeight.bold),
                    ),
          ),
        ],
      ),
    );
  }
}
