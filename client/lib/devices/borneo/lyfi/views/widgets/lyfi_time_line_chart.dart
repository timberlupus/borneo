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
  final DateTime currentTime;
  final bool allowZoom;
  final LineTouchData? lineTouchData;

  const LyfiTimeLineChart({
    super.key,
    required this.lineBarsData,
    required this.minX,
    required this.maxX,
    required this.minY,
    required this.maxY,
    required this.currentTime,
    this.extraVerticalLines,
    this.leftTitleBuilder,
    this.animationDuration = const Duration(milliseconds: 200),
    this.allowZoom = false,
    this.lineTouchData,
  });

  @override
  Widget build(BuildContext context) {
    final borderSide = BorderSide(color: Theme.of(context).colorScheme.surfaceDim, width: 1.5);
    final verticalLines = <VerticalLine>[];

    // 计算label高度
    final labelStyle = Theme.of(context).textTheme.labelMedium?.copyWith(
      color: Theme.of(context).colorScheme.primary,
      fontFeatures: [FontFeature.tabularFigures()],
    );
    final labelText = _formatTimeLabel(
      Duration(hours: currentTime.hour, minutes: currentTime.minute, seconds: currentTime.second).inSeconds.toDouble(),
    );
    final textPainter = TextPainter(
      text: TextSpan(text: labelText, style: labelStyle),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final labelHeight = textPainter.height;

    verticalLines.add(_buildNowLine(context, currentTime, labelHeight));
    if (extraVerticalLines != null) {
      verticalLines.addAll(extraVerticalLines!);
    }
    return LineChart(
      LineChartData(
        lineTouchData: lineTouchData ?? _defaultLineTouchData,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: (maxY - minY) * 0.25,
          verticalInterval: 3600 * 6,
          getDrawingHorizontalLine: (value) =>
              FlLine(color: Theme.of(context).colorScheme.surfaceDim, strokeWidth: 1.5),
          getDrawingVerticalLine: (value) => FlLine(color: Theme.of(context).colorScheme.surfaceDim, strokeWidth: 1.5),
        ),
        titlesData: FlTitlesData(
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              reservedSize: 16,
              interval: 3600 * 3,
              getTitlesWidget: (value, meta) {
                final text = _formatTimeLabel(value);
                return SideTitleWidget(
                  meta: meta,
                  space: 0,
                  child: Text(
                    text,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                    ),
                  ),
                );
              },
            ),
          ),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: leftTitleBuilder != null,
              reservedSize: 24,
              getTitlesWidget: (value, meta) {
                final text = leftTitleBuilder?.call(value) ?? '';
                return SideTitleWidget(
                  meta: meta,
                  child: Text(text, style: Theme.of(context).textTheme.labelSmall),
                );
              },
            ),
          ),
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
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
              maxScale: 2.5,
              panEnabled: true,
              scaleEnabled: true,
            )
          : const FlTransformationConfig(),
    );
  }

  LineTouchData get _defaultLineTouchData => LineTouchData(handleBuiltInTouches: true);

  VerticalLine _buildNowLine(BuildContext context, DateTime now, double labelHeight) {
    return VerticalLine(
      x: Duration(hours: now.hour, minutes: now.minute, seconds: now.second).inSeconds.toDouble(),
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
          Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.75),
        ],
      ),
      dashArray: const [3, 2],
      strokeWidth: 1.5,
      label: VerticalLineLabel(
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
          fontFeatures: [FontFeature.tabularFigures()],
          backgroundColor: Colors.transparent,
        ),
        padding: EdgeInsetsGeometry.zero,
        alignment: const Alignment(0, -1.5),
        show: true,
        labelResolver: (vl) => _formatTimeLabel(vl.x),
      ),
    );
  }

  String _formatTimeLabel(double seconds) {
    final d = Duration(seconds: seconds.round());
    final h = d.inHours.toString().padLeft(2, '0');
    final m = (d.inMinutes % 60).toString().padLeft(2, '0');
    return '$h:$m';
  }
}
