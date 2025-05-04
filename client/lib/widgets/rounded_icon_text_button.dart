import 'package:flutter/material.dart';

class RoundedIconTextButton extends StatefulWidget {
  final Widget icon;
  final String text;
  final VoidCallback? onPressed;
  final double borderRadius;
  final double buttonSize;
  final Color borderColor;
  final Color iconColor;
  final Color textColor;
  final EdgeInsetsGeometry padding;
  final double spacing;

  const RoundedIconTextButton({
    required this.icon,
    required this.text,
    required this.onPressed,
    this.borderRadius = 8.0,
    this.buttonSize = 48.0,
    this.borderColor = Colors.grey,
    this.iconColor = Colors.black,
    this.textColor = Colors.black,
    this.padding = const EdgeInsets.all(0),
    this.spacing = 4.0,
    super.key,
  });

  @override
  State<RoundedIconTextButton> createState() => _RoundedIconTextButtonState();
}

class _RoundedIconTextButtonState extends State<RoundedIconTextButton> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: widget.padding,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton.outlined(
            onPressed: widget.onPressed,
            style: OutlinedButton.styleFrom(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(widget.borderRadius)),
              backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
              side: BorderSide(color: widget.borderColor),
              padding: EdgeInsets.all(8),
            ),
            icon: widget.icon,
          ),
          SizedBox(height: widget.spacing),
          Text(widget.text, style: TextStyle(color: widget.textColor, fontSize: 12)),
        ],
      ),
    );
  }
}
