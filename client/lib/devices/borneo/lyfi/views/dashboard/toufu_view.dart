import 'package:flutter/material.dart';
import 'package:gauge_indicator/gauge_indicator.dart';

class DashboardToufu extends StatelessWidget {
  final String title;
  final double value;
  final double maxValue;
  final double minValue;
  final IconData? icon;
  final Widget? center;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? progressColor;
  final Color? arcColor;
  final List<GaugeSegment> segments;

  DashboardToufu({
    required this.title,
    required this.value,
    required this.center,
    required this.minValue,
    required this.maxValue,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.progressColor,
    this.arcColor,
    this.segments = const [],
    super.key,
  }) {
    assert(!minValue.isNaN);
    assert(!maxValue.isNaN);
    assert(!value.isNaN);
    assert(maxValue != 0);

    final minRounded = minValue.roundToDouble();
    final maxRounded = maxValue.roundToDouble();
    final valueRounded = value.roundToDouble();

    assert(minRounded <= maxRounded);
    assert(valueRounded >= minRounded && valueRounded <= maxRounded);
    assert(segments.every((segment) => !segment.from.isNaN && !segment.to.isNaN));
    assert(segments.every((segment) => segment.from <= segment.to));
    assert(segments.every((segment) => segment.from >= minRounded && segment.to <= maxRounded));
  }

  @override
  Widget build(BuildContext context) {
    final fgColor = foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final bgColor = backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer;
    final progColor = progressColor ?? Theme.of(context).colorScheme.primary;
    final arcColor = this.arcColor ?? Theme.of(context).colorScheme.onSurfaceVariant;

    final minRounded = minValue.roundToDouble();
    final maxRounded = maxValue.roundToDouble();
    final valueRounded = value.roundToDouble();

    return Card(
      margin: const EdgeInsets.all(0),
      color: bgColor,
      elevation: 0,
      child: AspectRatio(
        aspectRatio: 1,
        child: SizedBox(
          height: 200, // Provide bounded height
          child: LayoutBuilder(
            builder: (context, constraints) => Padding(
              padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
              child: Stack(
                clipBehavior: Clip.hardEdge, // Prevent overflow
                children: [
                  if (icon != null)
                    Positioned(
                      bottom: -constraints.maxHeight * 0.2,
                      right: -constraints.maxWidth * 0.2,
                      child: ClipRect(
                        child: Icon(icon!, size: constraints.maxWidth * 0.75, color: fgColor.withAlpha(8)),
                      ),
                    ),
                  Positioned.fill(
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: AnimatedRadialGauge(
                            initialValue: minRounded,
                            duration: const Duration(milliseconds: 1000),
                            curve: Curves.decelerate,
                            value: valueRounded,
                            radius: null,
                            axis: GaugeAxis(
                              min: minRounded,
                              max: maxRounded,
                              degrees: 270,
                              style: GaugeAxisStyle(
                                thickness: 10.5,
                                segmentSpacing: 0,
                                background: segments.isEmpty ? arcColor : null,
                                cornerRadius: Radius.zero,
                              ),
                              pointer: null,
                              progressBar: GaugeProgressBar.basic(color: progColor),
                              segments: segments,
                            ),
                            builder: (context, label, value) => Center(child: label),
                            child: center,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fgColor)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
