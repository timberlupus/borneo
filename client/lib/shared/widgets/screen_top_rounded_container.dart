import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:screen_corner_radius/screen_corner_radius.dart';

import '../../core/models/platform_device_info.dart';

/// A container that matches the device's screen top corner radii.
///
/// The corner radius is pulled from the shared [PlatformDeviceInfo]
/// provider which is populated at startup.  This class no longer queries the
/// plugin itself; if the provider is missing (tests, standalone usage) it
/// defaults to zero.
class ScreenTopRoundedContainer extends StatelessWidget {
  final Widget child;
  final Color? color;
  final EdgeInsetsGeometry? padding;
  final List<BoxShadow>? shadows;

  const ScreenTopRoundedContainer({super.key, required this.child, this.color, this.padding, this.shadows});

  @override
  Widget build(BuildContext context) {
    final bg = color ?? Theme.of(context).colorScheme.surface;

    // radius comes from the shared provider; fall back to zero if not
    // available so the widget remains usable in isolation (tests, etc.)
    final info = Provider.of<PlatformDeviceInfo?>(context, listen: false);
    final r = info?.screenCornerRadius ?? ScreenRadius.value(0.0);

    return ClipRRect(
      borderRadius: BorderRadius.only(topLeft: Radius.circular(r.topLeft), topRight: Radius.circular(r.topRight)),
      child: Container(
        decoration: BoxDecoration(color: bg, boxShadow: shadows),
        child: Padding(padding: padding ?? EdgeInsets.zero, child: child),
      ),
    );
  }
}
