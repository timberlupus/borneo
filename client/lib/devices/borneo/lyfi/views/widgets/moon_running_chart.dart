import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/widgets/lyfi_time_line_chart.dart';
import 'package:borneo_app/core/utils/hex_color.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

class MoonRunningChart extends StatelessWidget {
  final ScheduleTable moonInstants;
  final List<LyfiChannelInfo> channelInfoList;
  const MoonRunningChart({required this.moonInstants, required this.channelInfoList, super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
      child: LyfiTimeLineChart(
        lineBarsData: buildLineData(kLyfiBrightnessMax.toDouble()),
        minX: moonInstants.isNotEmpty ? moonInstants.first.instant.inSeconds.toDouble() : 0,
        maxX: moonInstants.isNotEmpty ? moonInstants.last.instant.inSeconds.toDouble() : 24 * 3600,
        minY: 0,
        maxY: 1.0,
      ),
    );
  }

  List<LineChartBarData> buildLineData(double maxBrightness) {
    final series = <LineChartBarData>[];
    for (int channelIndex = 0; channelIndex < channelInfoList.length; channelIndex++) {
      bool allZero = true;
      for (final instant in moonInstants) {
        if (instant.color[channelIndex] != 0) {
          allZero = false;
          break;
        }
      }
      if (allZero) {
        continue;
      }
      final spots = <FlSpot>[];
      for (final instant in moonInstants) {
        final normalizedY = maxBrightness > 0 ? instant.color[channelIndex] / maxBrightness : 0.0;
        spots.add(FlSpot(instant.instant.inSeconds.toDouble(), normalizedY));
      }
      final primaryColor = HexColor.fromHex(channelInfoList[channelIndex].color);
      series.add(
        LineChartBarData(
          spots: spots,
          isCurved: false,
          color: primaryColor,
          barWidth: 1.5,
          dotData: FlDotData(show: true),
          belowBarData: BarAreaData(show: false),
        ),
      );
    }
    return series;
  }
}
