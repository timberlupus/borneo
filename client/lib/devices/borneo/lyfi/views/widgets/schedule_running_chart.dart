import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/core/utils/hex_color.dart';
import 'package:borneo_common/datetime_ext.dart';
// import 'package:borneo_common/duration_ext.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'lyfi_time_line_chart.dart';

class ScheduleRunningChart extends StatelessWidget {
  const ScheduleRunningChart({super.key});

  @override
  Widget build(BuildContext context) {
    LyfiViewModel vm = context.read<LyfiViewModel>();
    if (!vm.isOnline) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: Selector<LyfiViewModel, DateTime>(
        selector: (context, vm) => vm.deviceClock,
        shouldRebuild: (previous, next) => !previous.isEqualToMinute(next),
        builder: (context, clock, _) {
          return LyfiTimeLineChart(
            lineBarsData: buildLineData(vm),
            minX: 0,
            maxX: 24 * 3600.0,
            minY: 0,
            maxY: lyfiBrightnessMax.toDouble(),
            currentTime: clock,
            allowZoom: true,
          );
        },
      ),
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
}
