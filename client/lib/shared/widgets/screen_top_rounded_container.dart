import 'package:flutter/material.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

/// A container that matches the device's screen top corner radii.
/// - Uses screen_corner_radius to query radii asynchronously.
/// - Falls back to 0 if plugin is unavailable or returns nulls.
class ScreenTopRoundedContainer extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;

  const ScreenTopRoundedContainer({super.key, required this.child, this.color, this.padding});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.surface;
    final future = ScreenCornerRadius.get().catchError((_) => ScreenRadius.zero());

    return FutureBuilder<ScreenRadius>(
      future: future,
      builder: (context, snapshot) {
        final r = snapshot.data ?? ScreenRadius.zero();
        return Container(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(topLeft: Radius.circular(r.topLeft), topRight: Radius.circular(r.topRight)),
          ),
          child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
        );
      },
    );
  }
}
