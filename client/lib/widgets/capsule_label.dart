import 'package:flutter/material.dart';

class CapsuleLabel extends StatelessWidget {
  final String label;
  final Color? backgroundColor;
  final Color textColor;
  final IconData? icon; // 可选的左边图标
  final Color iconColor; // 图标颜色
  final double padding;

  const CapsuleLabel({
    super.key,
    required this.label,
    this.backgroundColor,
    this.textColor = Colors.white,
    this.icon,
    this.iconColor = Colors.white,
    this.padding = 8.0,
  });

  @override
  Widget build(BuildContext context) {
    final bgColor = backgroundColor ?? Theme.of(context).primaryColor;
    final borderRadius = padding * 2;
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(borderRadius),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null)
            Padding(
              padding: const EdgeInsets.only(right: 4.0),
              child: Icon(
                icon,
                color: iconColor,
                size: 16.0,
              ),
            ),
          Text(
            label,
            style: TextStyle(
              color: textColor,
              fontSize: 14.0,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
