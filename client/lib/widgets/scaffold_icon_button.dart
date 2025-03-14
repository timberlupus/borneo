import 'package:flutter/material.dart';

class ScaffoldIconButton extends StatelessWidget {
  final void Function()? onPressed;
  final Widget icon;

  const ScaffoldIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Ink(
      height: 40,
      width: 40,
      padding: EdgeInsets.all(0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        shape: BoxShape.circle,
      ),
      child: IconButton(icon: icon, onPressed: onPressed),
    );
  }
}
