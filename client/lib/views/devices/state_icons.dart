import 'package:flutter/material.dart';

class FlashingIcon extends StatefulWidget {
  final Widget icon;
  final Duration duration;
  const FlashingIcon({
    required this.icon,
    this.duration = const Duration(milliseconds: 1000),
    super.key,
  });

  @override
  State<FlashingIcon> createState() => _FlashingIconState();
}

class _FlashingIconState extends State<FlashingIcon>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _animation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: widget.duration,
      vsync: this,
    )..repeat(reverse: true);

    _animation = CurvedAnimation(
      parent: _controller,
      curve: Curves.fastEaseInToSlowEaseOut,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _animation,
      builder: (context, child) {
        return Opacity(
          opacity: _animation.value,
          child: widget.icon,
        );
      },
    );
  }
}
