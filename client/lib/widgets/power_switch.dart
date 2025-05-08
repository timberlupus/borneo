import 'package:borneo_app/widgets/rounded_icon_text_button.dart';
import 'package:flutter/material.dart';

class PowerButton extends StatefulWidget {
  final bool value;
  final void Function(bool)? onChanged;
  final Widget label;

  const PowerButton({required this.value, required this.label, this.onChanged});

  @override
  _PowerButtonState createState() => _PowerButtonState();
}

class _PowerButtonState extends State<PowerButton> {
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final iconColor = widget.value ? Colors.green : colorScheme.error;
    final loadingColor = colorScheme.onSurface;

    return RoundedIconTextButton(
      onPressed: _isLoading || widget.onChanged == null ? null : () => widget.onChanged?.call(widget.value),
      borderColor: Theme.of(context).colorScheme.primary,
      text: widget.value ? 'ON' : 'OFF',
      buttonSize: 64,
      icon: AnimatedSwitcher(
        duration: Duration(milliseconds: 300),
        child:
            _isLoading
                ? CircularProgressIndicator(color: loadingColor, key: ValueKey('loading'))
                : Icon(
                  widget.value ? Icons.power_settings_new_outlined : Icons.power_settings_new,
                  key: ValueKey<bool>(widget.value),
                  size: 40,
                  color: iconColor,
                ),
      ),
    );
  }
}
