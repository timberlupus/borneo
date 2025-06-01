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
  });

  @override
  Widget build(BuildContext context) {
    final borderSide = BorderSide(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5);
    final verticalLines = <VerticalLine>[];
    verticalLines.add(_buildNowLine(context, currentTime));
    if (extraVerticalLines != null) {
      verticalLines.addAll(extraVerticalLines!);
    }
    return LineChart(
      LineChartData(
        lineTouchData: _lineTouchData,
        gridData: FlGridData(
          show: true,
          drawVerticalLine: false,
          drawHorizontalLine: true,
          horizontalInterval: (maxY - minY) * 0.25,
          verticalInterval: 3600 * 6,
          getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.surface, strokeWidth: 1.5),
          getDrawingVerticalLine: (value) => FlLine(color: Theme.of(context).colorScheme.surface, strokeWidth: 1.5),
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
                      color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(97),
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
                return SideTitleWidget(meta: meta, child: Text(text, style: Theme.of(context).textTheme.labelSmall));
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
      transformationConfig:
          allowZoom
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

  LineTouchData get _lineTouchData => LineTouchData(
    handleBuiltInTouches: true,
    touchTooltipData: LineTouchTooltipData(getTooltipColor: (touchedSpot) => Colors.black54.withAlpha(200)),
  );

  VerticalLine _buildNowLine(BuildContext context, DateTime now) {
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
        ),
        padding: const EdgeInsets.only(bottom: 8),
        alignment: const Alignment(0, -1.6),
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
