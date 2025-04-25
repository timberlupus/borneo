import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/easy_setup_screen.dart';
import 'package:borneo_app/infrastructure/duration.dart';
import 'package:borneo_app/infrastructure/time_of_day.dart';
import 'package:borneo_app/widgets/confirmation_sheet.dart';
import 'package:borneo_common/duration_ext.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/schedule_editor_view_model.dart';
import 'package:borneo_app/views/common/hex_color.dart';
import '../view_models/lyfi_view_model.dart';
import 'brightness_slider_list.dart';

class ScheduleEditorView extends StatelessWidget {
  const ScheduleEditorView({super.key});

  Future<Duration?> showNewInstantDialog(BuildContext context, TimeOfDay initialTime) async {
    bool isNextDay = false;
    final selectedTime = await showTimePicker(
      initialTime: initialTime,
      context: context,
      confirmText: 'Add time point',
      builder:
          (context, child) =>
              MediaQuery(data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true), child: child!),
    );
    return selectedTime?.toDuration();
  }

  Widget bottomTitleWidgets(BuildContext context, double value, TitleMeta meta) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
      fontFeatures: [FontFeature.tabularFigures()],
      color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(97),
    );

    final duration = Duration(seconds: value.toInt());
    return SideTitleWidget(
      space: 0,
      meta: meta,
      fitInside: SideTitleFitInsideData.fromTitleMeta(meta, distanceFromEdge: 0, enabled: false),
      child: Text(duration.toHH(), style: style, textAlign: TextAlign.right),
    );
  }

  Widget leftTitleWidgets(double value, TitleMeta meta) {
    const style = TextStyle(fontSize: 10, color: Colors.white54);
    return SideTitleWidget(meta: meta, child: Text('${value + 0.5}', style: style));
  }

  List<LineChartBarData> buildLineDatas(ScheduleEditorViewModel vm) {
    final series = <LineChartBarData>[];
    for (int channelIndex = 0; channelIndex < vm.channels.length; channelIndex++) {
      final spots = <FlSpot>[];
      //final sortedEntries = vm.entries.toList();
      //sortedEntries.sort((a, b) => a.instant.compareTo(b.instant));
      for (final entry in vm.entries) {
        double x = entry.instant.inSeconds.toDouble();
        double y = entry.channels[channelIndex].toDouble();
        final spot = FlSpot(x, y);
        spots.add(spot);
      }
      // Skip empty channel
      final channelColor = HexColor.fromHex(vm.deviceInfo.channels[channelIndex].color);
      series.add(
        LineChartBarData(
          isCurved: false,
          barWidth: 2,
          color: channelColor,
          dotData: const FlDotData(show: true),
          spots: spots,
        ),
      );
    }
    return series;
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: context.read<LyfiViewModel>().currentEditor! as ScheduleEditorViewModel,
      builder: (context, child) {
        final vm = context.read<ScheduleEditorViewModel>();
        return Column(
          spacing: 16,
          children: [
            // The chart
            Container(
              color: Theme.of(context).colorScheme.surfaceContainer,
              padding: EdgeInsets.fromLTRB(24, 16, 24, 8),
              child: AspectRatio(
                aspectRatio: 2.75,
                child: Consumer<ScheduleEditorViewModel>(
                  builder:
                      (context, vm, child) => Padding(
                        padding: EdgeInsets.fromLTRB(0, 16, 0, 0),
                        child: LineChart(
                          transformationConfig: FlTransformationConfig(
                            scaleAxis: FlScaleAxis.horizontal,
                            minScale: 1.0,
                            maxScale: 2.5,
                            panEnabled: true,
                            scaleEnabled: true,
                          ),
                          duration: Duration.zero,
                          LineChartData(
                            lineTouchData: const LineTouchData(enabled: true),
                            lineBarsData: buildLineDatas(vm),
                            // minX: 0,
                            // maxX: 24 * 3600,
                            minX: vm.entries.isNotEmpty ? vm.entries.first.instant.inHours.toDouble() * 3600.0 : 0.0,
                            maxX:
                                vm.entries.isNotEmpty
                                    ? (vm.entries.last.instant.inSeconds.toDouble() / 3600.0).ceilToDouble() * 3600
                                    : 24 * 3600,
                            minY: 0,
                            maxY: lyfiBrightnessMax.toDouble(),
                            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                            borderData: FlBorderData(
                              show: true,
                              border: Border.all(color: Theme.of(context).colorScheme.surface),
                            ),
                            titlesData: FlTitlesData(
                              leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                              bottomTitles: AxisTitles(
                                sideTitles: SideTitles(
                                  showTitles: true,
                                  interval: 3600 * 3,
                                  reservedSize: 16,
                                  getTitlesWidget: (v, m) => bottomTitleWidgets(context, v, m),
                                ),
                              ),
                            ),
                            gridData: FlGridData(
                              show: true,
                              drawVerticalLine: true,
                              drawHorizontalLine: true,
                              horizontalInterval: lyfiBrightnessMax.toDouble() * 0.25,
                              verticalInterval: 3600 * 3,
                              checkToShowVerticalLine: (value) => value.toInt() % 1800 == 0,
                              getDrawingHorizontalLine:
                                  (value) => FlLine(color: Theme.of(context).scaffoldBackgroundColor, strokeWidth: 1.5),
                              getDrawingVerticalLine:
                                  (value) => FlLine(color: Theme.of(context).scaffoldBackgroundColor, strokeWidth: 1.5),
                            ),
                            extraLinesData:
                                vm.currentEntry == null
                                    ? null
                                    : ExtraLinesData(
                                      extraLinesOnTop: false,
                                      verticalLines: [
                                        VerticalLine(
                                          x: vm.currentEntry!.instant.inSeconds.toDouble(),
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              Theme.of(context).colorScheme.primary.withValues(alpha: 0.75),
                                              Theme.of(context).colorScheme.surfaceContainer.withValues(alpha: 0.75),
                                            ],
                                          ),
                                          strokeWidth: 8,
                                          label: VerticalLineLabel(
                                            show: true,
                                            padding: const EdgeInsets.all(0),
                                            direction: LabelDirection.horizontal,
                                            alignment: Alignment(0, -1.5),
                                            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                              fontFeatures: [FontFeature.tabularFigures()],
                                              color: Theme.of(context).colorScheme.primary,
                                            ),
                                            labelResolver: (line) => Duration(seconds: line.x.toInt()).toHHMM(),
                                          ),
                                        ),
                                      ],
                                    ),
                          ),
                        ),
                      ),
                ),
              ),
            ),

            // Controls
            Expanded(
              child: Selector<ScheduleEditorViewModel, bool>(
                selector: (_, editor) => editor.canChangeColor,
                builder:
                    (_, canChangeColor, __) =>
                        BrightnessSliderList(context.read<ScheduleEditorViewModel>(), disabled: !canChangeColor),
              ),
            ),

            // Bottom buttons
            Consumer<ScheduleEditorViewModel>(
              builder:
                  (context, value, child) => Material(
                    elevation: 4,
                    color: Theme.of(context).colorScheme.primaryContainer,
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.auto_fix_high_outlined),
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          tooltip: 'Easy setup',
                          onPressed: () async {
                            if (context.mounted) {
                              bool proceed = true;
                              if (vm.isNotEmpty) {
                                proceed = await AsyncConfirmationSheet.show(
                                  context,
                                  message:
                                      'Using Easy Setup will clear your current dimming settings. Are you sure you want to proceed?',
                                );
                              }
                              if (proceed && context.mounted) {
                                await vm.easySetupEnter();
                                final route = MaterialPageRoute(builder: (context) => EasySetupScreen(vm));
                                if (context.mounted) {
                                  await Navigator.push(context, route);
                                  await vm.easySetupFinish();
                                }
                              }
                            }
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.play_arrow),
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          onPressed: vm.isOnline && !vm.isPreviewMode ? vm.togglePreviewMode : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_outlined),
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          onPressed: () async {
                            final initialTime =
                                (vm.currentEntry?.instant ?? Duration(hours: 6, minutes: 30)) +
                                ScheduleEditorViewModel.defaultInstantSpan;
                            final selectedTime = await showNewInstantDialog(context, initialTime.toTimeOfDay());
                            if (selectedTime != null) {
                              vm.addInstant(selectedTime);
                            }
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.remove_outlined),
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          onPressed: vm.canRemoveCurrentInstant ? vm.removeCurrentInstant : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.clear_outlined),
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                          onPressed: vm.canClearInstants ? () => _confirmClearEntries(context, vm) : null,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_previous_outlined),
                          onPressed: vm.canPrevInstant ? vm.prevInstant : null,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                        IconButton(
                          icon: const Icon(Icons.skip_next_outlined),
                          onPressed: vm.canNextInstant ? vm.nextInstant : null,
                          color: Theme.of(context).colorScheme.onPrimaryContainer,
                        ),
                      ],
                    ),
                  ),
            ),
          ],
        );
      },
    );
  }

  void _confirmClearEntries(BuildContext context, ScheduleEditorViewModel vm) {
    showModalBottomSheet(
      context: context,
      builder: (BuildContext context) {
        return Container(
          padding: EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text('Confirmation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              SizedBox(height: 16),
              Text('Are you sure you want to remove all schedule entries?'),
              SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: <Widget>[
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(false);
                    },
                    child: Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop(true);
                    },
                    child: Text('Confirm'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    ).then((value) {
      if (value != null && value) {
        vm.clearEntries();
      } else {
        //
      }
    });
  }
}
