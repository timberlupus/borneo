import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/views/common/hex_color.dart';
import 'package:borneo_common/datetime_ext.dart';
import 'package:borneo_common/duration_ext.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SunRunningChart extends StatelessWidget {
  final List<ScheduledInstant> sunInstants;
  final List<LyfiChannelInfo> channelInfoList;
  const SunRunningChart({required this.sunInstants, required this.channelInfoList, super.key});

  @override
  Widget build(BuildContext context) {
    LyfiViewModel vm = context.read<LyfiViewModel>();
    if (!vm.isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
      child: Selector<LyfiViewModel, DateTime>(
        selector: (context, vm) => vm.deviceClock,
        shouldRebuild: (previous, next) => !previous.isEqualToSecond(next),
        builder:
            (context, clock, _) => LineChart(_buildChartData(context), duration: const Duration(milliseconds: 200)),
      ),
    );
  }

  LineChartData _buildChartData(BuildContext context) {
    final borderSide = BorderSide(color: Theme.of(context).scaffoldBackgroundColor, width: 1.5);
    final double sunriseInstant =
        sunInstants.isNotEmpty ? (sunInstants.first.instant.inSeconds / 3600.0).floorToDouble() * 3600 : 0;
    final double sunsetInstant =
        sunInstants.isNotEmpty ? (sunInstants.last.instant.inSeconds / 3600.0).ceilToDouble() * 3600 : 0;
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
      lineBarsData: buildLineData(),
      minX: sunriseInstant,
      maxX: sunsetInstant,
      minY: 0,
      maxY: lyfiBrightnessMax.toDouble(),
      extraLinesData: _buildExtraLines(context),
    );
  }

  ExtraLinesData _buildExtraLines(BuildContext context) =>
      ExtraLinesData(extraLinesOnTop: true, verticalLines: [_buildNowLine(context)]);

  VerticalLine _buildNowLine(BuildContext context) {
    final now = context.read<LyfiViewModel>().deviceClock;
    return VerticalLine(
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

  List<LineChartBarData> buildLineData() {
    final series = <LineChartBarData>[];
    for (int channelIndex = 0; channelIndex < channelInfoList.length; channelIndex++) {
      final spots = <FlSpot>[];
      //final sortedEntries = vm.entries.toList();
      //sortedEntries.sort((a, b) => a.instant.compareTo(b.instant));
      for (final entry in sunInstants) {
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
          color: HexColor.fromHex(channelInfoList[channelIndex].color),
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
    ).textTheme.labelSmall?.copyWith(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6));
    final instant = Duration(seconds: value.round().toInt()).toHHMM();
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
