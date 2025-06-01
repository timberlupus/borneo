import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/views/common/hex_color.dart';
import 'package:borneo_common/datetime_ext.dart';
import 'package:borneo_common/duration_ext.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ScheduleRunningChart extends StatelessWidget {
  const ScheduleRunningChart({super.key});

  @override
  Widget build(BuildContext context) {
    LyfiViewModel vm = context.read<LyfiViewModel>();
    if (!vm.isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: Selector<LyfiViewModel, DateTime>(
        selector: (context, vm) => vm.deviceClock,
        shouldRebuild: (previous, next) => !previous.isEqualToMinute(next),
        builder:
            (context, clock, _) => LineChart(
              _buildChartData(context, vm),
              duration: const Duration(milliseconds: 250),
              transformationConfig: FlTransformationConfig(
                scaleAxis: FlScaleAxis.horizontal,
                minScale: 1.0,
                maxScale: 2.5,
                panEnabled: true,
                scaleEnabled: true,
              ),
            ),
      ),
    );
  }

  LineChartData _buildChartData(BuildContext context, LyfiViewModel vm) {
    final now = vm.deviceClock;
    final borderSide = BorderSide(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5);
    return LineChartData(
      lineTouchData: lineTouchData1,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        drawHorizontalLine: true,
        horizontalInterval: lyfiBrightnessMax.toDouble() * 0.25,
        verticalInterval: 3600 * 6,
        getDrawingHorizontalLine: (value) => FlLine(color: Theme.of(context).colorScheme.surface, strokeWidth: 1.5),
        getDrawingVerticalLine: (value) => FlLine(color: Theme.of(context).colorScheme.surface, strokeWidth: 1.5),
      ),
      titlesData: _makeTitlesData(context),
      borderData: FlBorderData(
        show: true,
        border: Border(bottom: borderSide, left: borderSide, right: borderSide, top: borderSide),
      ),
      lineBarsData: buildLineData(vm),
      minX: 0,
      maxX: 24 * 3600.0,
      minY: 0,
      maxY: lyfiBrightnessMax.toDouble(),
      extraLinesData: ExtraLinesData(
        extraLinesOnTop: true,
        verticalLines: [
          if (vm.isOn && vm.isOnline)
            VerticalLine(
              x:
                  Duration(
                    hours: now.hour.toInt(),
                    minutes: now.minute.toInt(),
                    seconds: now.second.toInt(),
                  ).inSeconds.toDouble(),
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
                labelResolver: (vl) => Duration(seconds: vl.x.toInt()).toHHMM(),
              ),
            ),
        ],
      ),
    );
  }

  LineTouchData get lineTouchData1 => LineTouchData(
    handleBuiltInTouches: true,
    touchTooltipData: LineTouchTooltipData(getTooltipColor: (touchedSpot) => Colors.black54.withAlpha(200)),
  );

  FlTitlesData _makeTitlesData(BuildContext context) {
    return FlTitlesData(
      bottomTitles: AxisTitles(sideTitles: _bottomTitles(context)),
      rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  List<LineChartBarData> buildLineData(LyfiViewModel vm) {
    final series = <LineChartBarData>[];
    for (int channelIndex = 0; channelIndex < vm.channels.length; channelIndex++) {
      final spots = <FlSpot>[];
      //final sortedEntries = vm.entries.toList();
      //sortedEntries.sort((a, b) => a.instant.compareTo(b.instant));
      final instants = vm.scheduledInstants;
      for (final entry in instants) {
        double x = entry.instant.inSeconds.toDouble();
        double y = entry.color[channelIndex].toDouble();
        final spot = FlSpot(x, y);
        spots.add(spot);
      }
      // Skip empty channel
      series.add(
        LineChartBarData(
          isCurved: false,
          barWidth: 2.5,
          color: HexColor.fromHex(vm.lyfiDeviceInfo.channels[channelIndex].color),
          dotData: const FlDotData(show: false),
          spots: spots,
        ),
      );
    }
    return series;
  }

  Widget bottomTitleWidgets(BuildContext context, double value, TitleMeta meta) {
    final style = Theme.of(
      context,
    ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(97));
    final instant = Duration(seconds: value.round().toInt()).toHH();
    final text = Text(instant, style: style);
    return SideTitleWidget(meta: meta, space: 0, child: text);
  }

  SideTitles _bottomTitles(BuildContext context) {
    return SideTitles(
      showTitles: true,
      reservedSize: 16,
      interval: 3600 * 3,
      getTitlesWidget: (v, m) => bottomTitleWidgets(context, v, m),
    );
  }

  FlGridData get gridData => const FlGridData(show: true);
}
