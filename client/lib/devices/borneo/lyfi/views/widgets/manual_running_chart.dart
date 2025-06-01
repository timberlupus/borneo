import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/color_chart.dart';
import 'package:borneo_app/views/common/hex_color.dart';
import 'package:borneo_app/widgets/value_listenable_builders.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class ManualRunningChart extends StatelessWidget {
  const ManualRunningChart({super.key});

  List<BarChartGroupData> buildGroupDataItems(BuildContext context) {
    final vm = context.read<LyfiViewModel>();
    if (vm.lyfiDeviceInfo.channels.isEmpty || vm.channels.isEmpty) {
      return [];
    }
    int index = 0;
    return vm.lyfiDeviceInfo.channels.map((ch) {
      final channel = vm.channels[index];
      final g = makeGroupData(context, ch, index, channel.value.toDouble());
      index++;
      return g;
    }).toList();
  }

  BarChartGroupData makeGroupData(BuildContext context, LyfiChannelInfo ch, int x, double y) {
    final primaryColor = HexColor.fromHex(ch.color);
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          borderRadius: BorderRadius.circular(5),
          toY: y,
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [primaryColor, Color.lerp(primaryColor, Colors.white, 0.7)!],
          ),
          width: 16,
          backDrawRodData: BackgroundBarChartRodData(
            show: true,
            fromY: 0,
            toY: lyfiBrightnessMax.toDouble(),
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
      ],
    );
  }

  Widget buildTitles(BuildContext context, double value) {
    final vm = context.read<LyfiViewModel>();
    final index = value.toInt();
    final ch = vm.lyfiDeviceInfo.channels[index];
    return Text(
      ch.name,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.read<LyfiViewModel>();
    assert(vm.isOnline);
    return MultiValueListenableBuilder<int>(
      valueNotifiers: vm.channels,
      builder:
          (context, values, _) => Padding(
            padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
            child: LyfiColorChart(
              BarChartData(
                barGroups: buildGroupDataItems(context),
                titlesData: FlTitlesData(
                  show: true,
                  bottomTitles: AxisTitles(
                    sideTitles: SideTitles(
                      showTitles: true,
                      getTitlesWidget: (value, _) => buildTitles(context, value),
                    ),
                  ),
                  leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                  rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                ),
                borderData: FlBorderData(show: false),
                barTouchData: BarTouchData(enabled: true),
                gridData: FlGridData(show: false),
              ),
            ),
          ),
    );
  }
}
