import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'dart:io';

/// A confirmation/apply button for the right side of an AppBar.
/// Supports icon and text combinations; at least one must be provided.
class AppBarApplyButton extends StatelessWidget {
  /// Button text (e.g. "Apply", "Confirm", "Save").
  final String? label;

  /// Button icon (e.g. Icons.check, CupertinoIcons.checkmark).
  final IconData? icon;

  /// Callback when pressed.
  final VoidCallback? onPressed;

  /// Whether the button is enabled.
  final bool enabled;

  /// Custom text style (optional).
  final TextStyle? labelStyle;

  const AppBarApplyButton({super.key, this.onPressed, this.enabled = true, this.labelStyle, this.label, this.icon})
    : assert(label != null || icon != null, 'label or icon must be provided');

  bool get _isIOS => Platform.isIOS || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = enabled
        ? (_isIOS ? CupertinoColors.systemBlue : theme.colorScheme.primary)
        : (_isIOS ? CupertinoColors.inactiveGray : theme.disabledColor);

    if (label == null && icon != null) {
      return IconButton(
        icon: Icon(icon, color: color),
        onPressed: enabled ? onPressed : null,
      );
    }

    if (label != null && icon == null) {
      return _buildTextButton(context, color);
    }

    return _buildCombinedButton(context, color);
  }

  Widget _buildTextButton(BuildContext context, Color color) {
    final textStyle =
        labelStyle ??
        TextStyle(
          color: color,
          fontSize: _isIOS ? 17 : 14,
          fontWeight: _isIOS ? FontWeight.w400 : FontWeight.w500,
          letterSpacing: _isIOS ? 0 : 1.25,
        );

    if (_isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        onPressed: enabled ? onPressed : null,
        child: Text(label!, style: textStyle),
      );
    }

    return TextButton(
      onPressed: enabled ? onPressed : null,
      child: Text(label!.toUpperCase(), style: textStyle),
    );
  }

  Widget _buildCombinedButton(BuildContext context, Color color) {
    final textStyle =
        labelStyle ??
        TextStyle(color: color, fontSize: _isIOS ? 17 : 14, fontWeight: _isIOS ? FontWeight.w400 : FontWeight.w500);

    if (_isIOS) {
      return CupertinoButton(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        onPressed: enabled ? onPressed : null,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(width: 4),
            Text(label!, style: textStyle),
          ],
        ),
      );
    }

    return TextButton.icon(
      onPressed: enabled ? onPressed : null,
      icon: Icon(icon, color: color, size: 18),
      label: Text(label!.toUpperCase(), style: textStyle),
    );
  }
}
