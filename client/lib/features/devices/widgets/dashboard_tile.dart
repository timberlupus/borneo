import 'package:flutter/material.dart';

/// A generic dashboard tile wrapper used throughout the Lyfi dashboard.
///
/// Provides a consistent aspect ratio, rounded corners, background color and
/// Material/InkWell behaviour.  Clients supply the inner content via [child]
/// and may optionally specify callbacks or disable interaction.
class DashboardTile extends StatelessWidget {
  /// The contents placed inside the tile. Usually a [Row] with icon/text.
  final Widget child;

  /// Aspect ratio for the tile. Defaults to 2.0 (wide rectangle).
  final double aspectRatio;

  /// Padding around [child], applied inside the InkWell.
  final EdgeInsetsGeometry padding;

  /// Radius applied to the tile corners.
  final BorderRadiusGeometry? borderRadius;

  /// Standard corner radius used by most tiles.
  ///
  /// Other widgets (e.g. badges) can reference this to align their sizes
  /// with the rounded rectangle.
  static const double cornerRadius = 16.0;

  /// Background colour of the tile. Falls back to
  /// Theme.of(context).colorScheme.surfaceContainerHighest.
  final Color? backgroundColor;

  /// An optional widget that is stacked *beneath* the InkWell but above the
  /// background colour. Useful for things like the power brightness bar.
  final Widget? backgroundOverlay;

  /// Whether the tile is disabled. When true the ripple is suppressed and the
  /// callbacks will not be invoked.
  final bool disabled;

  /// Called when the tile is tapped.
  final VoidCallback? onPressed;

  /// Called when the tile is long pressed.
  final VoidCallback? onLongPressed;

  const DashboardTile({
    required this.child,
    this.aspectRatio = 2.0,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
    this.borderRadius = const BorderRadius.all(Radius.circular(cornerRadius)),
    this.backgroundColor,
    this.backgroundOverlay,
    this.onPressed,
    this.onLongPressed,
    this.disabled = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bg = backgroundColor ?? theme.colorScheme.surfaceContainerHighest;
    return AspectRatio(
      aspectRatio: aspectRatio,
      child: ClipRRect(
        borderRadius: borderRadius ?? BorderRadius.zero,
        child: Stack(
          children: [
            Container(color: bg),
            ?backgroundOverlay,
            Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: (borderRadius is BorderRadius ? borderRadius as BorderRadius : BorderRadius.zero),
                onTap: disabled ? null : onPressed,
                onLongPress: disabled ? null : onLongPressed,
                splashColor: disabled ? Colors.transparent : null,
                child: Padding(padding: padding, child: child),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A 1:1 variant of [DashboardTile].
///
/// Adds support for an optional red "alarm" badge in the top-right corner.
class SmallDashboardTile extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius? borderRadius;
  final Color? backgroundColor;
  final Widget? backgroundOverlay;
  final bool disabled;
  final VoidCallback? onPressed;
  final VoidCallback? onLongPressed;

  /// When true a small red circle is painted in the top‑right.
  final bool alarm;

  const SmallDashboardTile({
    required this.child,
    this.padding = const EdgeInsets.all(8),
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.backgroundColor,
    this.backgroundOverlay,
    this.onPressed,
    this.onLongPressed,
    this.disabled = false,
    this.alarm = false,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    Widget base = DashboardTile(
      aspectRatio: 1,
      padding: padding,
      borderRadius: borderRadius,
      backgroundColor: backgroundColor,
      backgroundOverlay: backgroundOverlay,
      disabled: disabled,
      onPressed: onPressed,
      onLongPressed: onLongPressed,
      child: child,
    );

    if (!alarm) return base;

    return Stack(
      clipBehavior: Clip.none,
      children: [
        base,
        Positioned(
          top: 4,
          right: 4,
          child: Container(
            width: 12,
            height: 12,
            decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
          ),
        ),
      ],
    );
  }
}
