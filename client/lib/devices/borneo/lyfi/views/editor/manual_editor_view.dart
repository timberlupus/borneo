import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/brightness_slider_list.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/color_chart.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/views/common/hex_color.dart';
import 'package:borneo_app/widgets/value_listenable_builders.dart';
import '../../view_models/editor/manual_editor_view_model.dart';

class ManualEditorView extends StatelessWidget {
  const ManualEditorView({super.key});

  Widget buildSliders(BuildContext context) {
    return Selector<ManualEditorViewModel, ({bool isInitialized, bool canChangeColor})>(
      selector: (context, vm) => (canChangeColor: vm.canChangeColor, isInitialized: vm.isInitialized),
      builder: (context, props, _) {
        if (props.isInitialized) {
          return BrightnessSliderList(context.read<ManualEditorViewModel>(), disabled: !props.canChangeColor);
        } else {
          return Container();
        }
      },
    );
  }

  List<BarChartGroupData> buildGroupDataItems(BuildContext context, ManualEditorViewModel vm) {
    int index = 0;
    if (vm.isInitialized) {
      return vm.deviceInfo.channels.map((ch) {
        final channel = vm.channels[index];
        final g = makeGroupData(context, ch, index, channel.value.toDouble());
        index++;
        return g;
      }).toList();
    } else {
      return [];
    }
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

  Widget buildTitles(BuildContext context, ManualEditorViewModel vm, double value) {
    if (vm.isInitialized) {
      final index = value.toInt();
      final ch = vm.deviceInfo.channels[index];
      return Text(ch.name, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor));
    } else {
      return Text("N/A");
    }
  }

  Widget buildGraph(BuildContext context) {
    return Consumer<ManualEditorViewModel>(
      builder: (context, vm, _) {
        return MultiValueListenableBuilder<int>(
          valueNotifiers: vm.channels,
          builder:
              (context, values, _) => LyfiColorChart(
                BarChartData(
                  barGroups: buildGroupDataItems(context, vm),
                  titlesData: FlTitlesData(
                    show: true,
                    bottomTitles: AxisTitles(
                      axisNameSize: 24,
                      sideTitles: SideTitles(
                        reservedSize: 24,
                        showTitles: true,
                        getTitlesWidget: (value, _) => buildTitles(context, vm, value),
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
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final editor = context.read<LyfiViewModel>().currentEditor;
    if (editor == null) {
      return const SizedBox.shrink();
    }
    return ChangeNotifierProvider.value(
      value: editor as ManualEditorViewModel,
      builder:
          (context, child) => Column(
            spacing: 16,
            children: [
              Container(
                color: Theme.of(context).colorScheme.surfaceContainer,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: AspectRatio(aspectRatio: 2.75, child: buildGraph(context)),
              ),
              Expanded(child: buildSliders(context)),
            ],
          ),
    );
  }
}
