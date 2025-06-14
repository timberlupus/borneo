import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/widgets/lyfi_time_line_chart.dart';
import 'package:borneo_app/core/utils/hex_color.dart';
import 'package:borneo_common/datetime_ext.dart';
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
      padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Selector<LyfiViewModel, DateTime>(
        selector: (context, vm) => vm.deviceClock,
        shouldRebuild: (previous, next) => !previous.isEqualToSecond(next),
        builder: (context, clock, _) {
          final double sunriseInstant = sunInstants.isNotEmpty
              ? (sunInstants.first.instant.inSeconds / 3600.0).floorToDouble() * 3600
              : 0;
          final double sunsetInstant = sunInstants.isNotEmpty
              ? (sunInstants.last.instant.inSeconds / 3600.0).ceilToDouble() * 3600
              : 0;
          return LyfiTimeLineChart(
            lineBarsData: buildLineData(),
            minX: sunriseInstant,
            maxX: sunsetInstant,
            minY: 0,
            maxY: lyfiBrightnessMax.toDouble(),
            currentTime: clock,
          );
        },
      ),
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
}
