import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class LyfiTimeLineChart extends StatelessWidget {
  final List<LineChartBarData> lineBarsData;
  final double minX;
  final double maxX;
  final double minY;
  final double maxY;
  final List<VerticalLine>? extraVerticalLines;
  final String? Function(double value)? leftTitleBuilder;
  final Duration animationDuration;
  final Duration? currentTime;
  final bool allowZoom;
  final LineTouchData? lineTouchData;
  final double labelAngleRadians;
  final double? maxScale;

  const LyfiTimeLineChart({
    super.key,
    required this.lineBarsData,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    this.currentTime,
    this.extraVerticalLines,
    this.leftTitleBuilder,
    this.animationDuration = const Duration(milliseconds: 200),
    this.allowZoom = false,
    this.lineTouchData,
    this.labelAngleRadians = 0, //math.pi / 4,
    this.maxScale,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final borderSide = BorderSide(color: cs.outlineVariant, width: 1);
    final verticalLines = <VerticalLine>[];

    final labelStyle = Theme.of(
      context,
    ).textTheme.labelMedium?.copyWith(color: cs.onPrimary, fontFeatures: [FontFeature.tabularFigures()]);
    if (currentTime != null) {
      final labelText = _formatNowLabel(currentTime!.inSeconds.toDouble());
      final textPainter = TextPainter(
        text: TextSpan(text: labelText, style: labelStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      final labelHeight = textPainter.height;

      verticalLines.add(_buildNowLine(context, currentTime!, labelHeight));
    }
    final xInterval = _resolveTimeInterval(minX, maxX);
    if (extraVerticalLines != null) {
      verticalLines.addAll(extraVerticalLines!);
    }
    return LineChart(
      LineChartData(
        lineTouchData: lineTouchData ?? _defaultLineTouchData,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: true,
          drawHorizontalLine: true,
          horizontalInterval: (maxY - minY) * 0.25,
          verticalInterval: xInterval,
          getDrawingHorizontalLine: (value) => FlLine(color: cs.outlineVariant, strokeWidth: 1.0),
          getDrawingVerticalLine: (value) => FlLine(color: cs.outlineVariant, strokeWidth: 1.0),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 28,
              interval: xInterval,
              getTitlesWidget: (value, meta) {
                final text = _formatAxisLabel(value);
                return SideTitleWidget(
                  angle: labelAngleRadians,
                  meta: meta,
                  space: 4,
                  child: Padding(
                    padding: const EdgeInsets.only(top: 0),
                    child: Text(
                      text,
                      textAlign: TextAlign.center,
                      style: Theme.of(
                        context,
                      ).textTheme.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 9),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              interval: _resolvePercentInterval(minY, maxY),
              getTitlesWidget: (value, meta) {
                final text = leftTitleBuilder?.call(value) ?? _formatPercentLabel(value, minY, maxY);
                return SideTitleWidget(
                  meta: meta,
                  child: Text(
                    text,
                    style: Theme.of(
                      context,
                    ).textTheme.labelSmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.38), fontSize: 8),
                  ),
                );
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 32,
              getTitlesWidget: (value, meta) => SideTitleWidget(meta: meta, child: const SizedBox.shrink()),
            ),
          ),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
        ),
        borderData: FlBorderData(
          show: true,
          border: Border(bottom: borderSide, left: borderSide, right: borderSide, top: borderSide),
        ),
        lineBarsData: lineBarsData,
        minX: minX,
        maxX: maxX,
        minY: minY,
        maxY: maxY,
        extraLinesData: ExtraLinesData(extraLinesOnTop: true, verticalLines: verticalLines),
      ),
      duration: animationDuration,
      transformationConfig: allowZoom
          ? FlTransformationConfig(
              scaleAxis: FlScaleAxis.horizontal,
              minScale: 1.0,
              maxScale: maxScale ?? 2.5,
              panEnabled: true,
              scaleEnabled: true,
            )
          : const FlTransformationConfig(),
    );
  }

  LineTouchData get _defaultLineTouchData => LineTouchData(handleBuiltInTouches: true);

  VerticalLine _buildNowLine(BuildContext context, Duration now, double labelHeight) {
    return VerticalLine(
      x: now.inSeconds.toDouble(),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
          Theme.of(context).scaffoldBackgroundColor.withValues(alpha: 0.75),
        ],
      ),
      strokeWidth: 3,
      label: VerticalLineLabel(
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontFeatures: [FontFeature.tabularFigures()],
          backgroundColor: Colors.transparent,
        ),
        padding: EdgeInsetsGeometry.zero,
        alignment: const Alignment(0, -1.5),
        show: true,
        labelResolver: (vl) => _formatNowLabel(vl.x),
      ),
    );
  }

  String _formatAxisLabel(double seconds) {
    final d = Duration(seconds: seconds.round());
    if (d.inHours == 24 && d.inMinutes % 60 == 0) {
      return '24:00';
    }
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    if (d.inHours >= 24) {
      return '$h:$m\nD2';
    }
    return '$h:$m';
  }

  String _formatNowLabel(double seconds) {
    final d = Duration(seconds: seconds.round());
    final hours = d.inHours % 24;
    final minutes = d.inMinutes % 60;
    final h = hours.toString().padLeft(2, '0');
    final m = minutes.toString().padLeft(2, '0');
    if (d.inHours >= 24) {
      return '$h:$m·D2';
    }
    return '$h:$m';
  }

  double _resolveTimeInterval(double minX, double maxX) {
    const intervals = <double>[3 * 3600.0, 4 * 3600.0, 6 * 3600.0, 12 * 3600.0];
    final span = (maxX - minX).abs();
    if (span <= 0) {
      return intervals.first;
    }
    for (final interval in intervals) {
      if (span <= interval * 2) {
        return interval;
      }
    }
    return intervals.last;
  }

  double _resolvePercentInterval(double minY, double maxY) {
    final span = (maxY - minY).abs();
    if (span <= 0) {
      return 1;
    }
    return span * 0.25;
  }

  String _formatPercentLabel(double value, double minY, double maxY) {
    final span = (maxY - minY).abs();
    if (span <= 0) {
      return '0%';
    }
    final percent = (((value - minY) / span) * 100).round();
    return '${percent.clamp(0, 100)}%';
  }
}
