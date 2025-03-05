import 'package:borneo_app/widgets/power_switch.dart';
import 'package:borneo_app/widgets/value_listenable_builders.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:borneo_common/duration_ext.dart';

import 'package:borneo_app/views/common/hex_color.dart';
import 'package:slide_to_act/slide_to_act.dart';
import '../view_models/lyfi_view_model.dart';
import 'color_chart.dart';

class ScheduleRunningChart extends StatelessWidget {
  const ScheduleRunningChart({super.key});

  @override
  Widget build(BuildContext context) {
    LyfiViewModel vm = context.read<LyfiViewModel>();
    return Container(
      padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: LineChart(
        _buildChartData(context, vm),
        duration: const Duration(milliseconds: 250),
      ),
    );
  }

  LineChartData _buildChartData(BuildContext context, LyfiViewModel vm) {
    final now = DateTime.now();
    final borderSide = BorderSide(
        color: Theme.of(context).scaffoldBackgroundColor, width: 1.5);
    return LineChartData(
      lineTouchData: lineTouchData1,
      gridData: FlGridData(
        show: true,
        drawVerticalLine: false,
        drawHorizontalLine: true,
        horizontalInterval: 25.0,
        verticalInterval: 3600 * 6,
        getDrawingHorizontalLine: (value) => FlLine(
          color: Theme.of(context).colorScheme.surface,
          strokeWidth: 1.5,
        ),
        getDrawingVerticalLine: (value) => FlLine(
          color: Theme.of(context).colorScheme.surface,
          strokeWidth: 1.5,
        ),
      ),
      titlesData: _makeTitlesData(context),
      borderData: FlBorderData(
        show: true,
        border: Border(
          bottom: borderSide,
          left: borderSide,
          right: borderSide,
          top: borderSide,
        ),
      ),
      lineBarsData: buildLineData(vm),
      minX: 0,
      maxX: 24 * 3600.0,
      minY: 0,
      maxY: 100,
      extraLinesData: ExtraLinesData(
        extraLinesOnTop: false,
        verticalLines: [
          if (vm.isOn && vm.isOnline)
            VerticalLine(
              x: Duration(
                hours: now.hour.toInt(),
                minutes: now.minute.toInt(),
                seconds: now.second.toInt(),
              ).inSeconds.toDouble(),
              gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Theme.of(context)
                        .colorScheme
                        .primary
                        .withValues(alpha: 0.75),
                    Theme.of(context).colorScheme.surfaceContainer,
                  ]),
              strokeWidth: 8,
              label: VerticalLineLabel(
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                padding: const EdgeInsets.all(0),
                alignment: Alignment(0, -1.8),
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
        touchTooltipData: LineTouchTooltipData(
          getTooltipColor: (touchedSpot) => Colors.black54.withOpacity(0.8),
        ),
      );

  FlTitlesData _makeTitlesData(BuildContext context) {
    return FlTitlesData(
      bottomTitles: AxisTitles(
        sideTitles: _bottomTitles(context),
      ),
      rightTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      topTitles: const AxisTitles(
        sideTitles: SideTitles(showTitles: false),
      ),
      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
    );
  }

  List<LineChartBarData> buildLineData(LyfiViewModel vm) {
    final series = <LineChartBarData>[];
    for (int channelIndex = 0;
        channelIndex < vm.channels.length;
        channelIndex++) {
      final spots = <FlSpot>[];
      //final sortedEntries = vm.entries.toList();
      //sortedEntries.sort((a, b) => a.instant.compareTo(b.instant));
      for (final entry in vm.scheduledInstants) {
        double x = entry.instant.inSeconds.toDouble();
        double y = entry.color[channelIndex].toDouble();
        final spot = FlSpot(x, y);
        spots.add(spot);
      }
      // Skip empty channel
      series.add(LineChartBarData(
        isCurved: false,
        barWidth: 2,
        color: HexColor.fromHex(vm.lyfiDeviceInfo.channels[channelIndex].color),
        dotData: const FlDotData(show: false),
        spots: spots,
      ));
    }
    return series;
  }

  Widget bottomTitleWidgets(
      BuildContext context, double value, TitleMeta meta) {
    final style = Theme.of(context).textTheme.labelSmall?.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant.withAlpha(97));
    final instant = Duration(seconds: value.round().toInt()).toHH();
    final text = Text(
      instant,
      style: style,
    );
    return SideTitleWidget(
      meta: meta,
      space: 0,
      child: text,
    );
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

class ManualRunningChart extends StatelessWidget {
  const ManualRunningChart({super.key});

  List<BarChartGroupData> buildGroupDataItems(
      BuildContext context, LyfiViewModel vm) {
    int index = 0;
    return vm.lyfiDeviceInfo.channels.map((ch) {
      final channel = vm.channels[index];
      final g = makeGroupData(context, ch, index, channel.value.toDouble());
      index++;
      return g;
    }).toList();
  }

  BarChartGroupData makeGroupData(
      BuildContext context, LyfiChannelInfo ch, int x, double y) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          borderRadius: BorderRadius.circular(5),
          toY: y,
          color: HexColor.fromHex(ch.color),
          width: 16,
          backDrawRodData: BackgroundBarChartRodData(
              show: true,
              fromY: 0,
              toY: ch.powerRatio.toDouble(),
              color: Theme.of(context).scaffoldBackgroundColor),
        ),
      ],
    );
  }

  Widget buildTitles(BuildContext context, LyfiViewModel vm, double value) {
    final index = value.toInt();
    final ch = vm.lyfiDeviceInfo.channels[index];
    return Text(ch.name,
        style: Theme.of(context)
            .textTheme
            .bodySmall
            ?.copyWith(color: Theme.of(context).colorScheme.onSurface));
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.read<LyfiViewModel>();
    if (vm.isOnline) {
      return Consumer<LyfiViewModel>(
          builder: (context, vm, _) => MultiValueListenableBuilder<int>(
              valueNotifiers: vm.channels,
              builder: (context, values, _) => Padding(
                  padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: LyfiColorChart(
                    BarChartData(
                      barGroups: buildGroupDataItems(context, vm),
                      titlesData: FlTitlesData(
                        show: true,
                        bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                          showTitles: true,
                          getTitlesWidget: (value, _) =>
                              buildTitles(context, vm, value),
                        )),
                        leftTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        topTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                        rightTitles: const AxisTitles(
                            sideTitles: SideTitles(showTitles: false)),
                      ),
                      borderData: FlBorderData(show: false),
                      barTouchData: BarTouchData(
                        enabled: true,
                      ),
                      gridData: FlGridData(show: false),
                    ),
                  ))));
    } else {
      return Center(
          child: Text("Device Offline.",
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: theme.colorScheme.error)));
    }
  }
}

class DashboardToufu extends StatelessWidget {
  final String title;
  final double value;
  final IconData? icon;
  final Widget? center;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? progressColor;
  final Color? arcColor;

  const DashboardToufu({
    required this.title,
    required this.value,
    required this.center,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.progressColor,
    this.arcColor,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = foregroundColor ?? Theme.of(context).colorScheme.onSurface;
    final bgColor =
        backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer;
    final progColor = progressColor ?? Theme.of(context).colorScheme.primary;
    final arcColor =
        this.arcColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.all(0),
      color: bgColor,
      elevation: 0,
      child: LayoutBuilder(
        builder: (context, constraints) => Stack(children: [
          if (icon != null)
            Positioned(
              bottom: -constraints.maxHeight * 0.15,
              right: -constraints.maxWidth * 0.15,
              child: Icon(
                icon!,
                size: constraints.maxWidth * 0.75,
                color: fgColor.withAlpha(8),
              ),
            ),
          Positioned.fill(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16.0, 24, 16, 8),
              child: Column(
                  mainAxisSize: MainAxisSize.max,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            CircularPercentIndicator(
                          radius: (constraints.maxHeight) / 2.0,
                          lineWidth: 10.0,
                          circularStrokeCap: CircularStrokeCap.butt,
                          animateFromLastPercent: true,
                          animation: true,
                          curve: Curves.decelerate,
                          arcType: ArcType.FULL,
                          percent: value,
                          center: center,
                          arcBackgroundColor: arcColor,
                          progressColor: progColor,
                        ),
                      ),
                    ),
                    Text(
                      title,
                      style: Theme.of(context)
                          .textTheme
                          .titleSmall
                          ?.copyWith(color: fgColor),
                    ),
                  ]),
            ),
          ),
        ]),
      ),
    );
  }
}

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.max,
        children: [
          // Chart
          LayoutBuilder(
            builder: (context, constraints) => AspectRatio(
              aspectRatio: 3,
              child: Container(
                color: Theme.of(context).colorScheme.surfaceContainer,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  margin: EdgeInsets.all(0),
                  child: Column(children: [
                    /*
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Row(children: [
                  Selector<LyfiViewModel, ({bool schedulerEnabled})>(
                      selector: (_, vm) =>
                          (schedulerEnabled: vm.schedulerEnabled,),
                      builder: (context, vm, _) {
                        if (vm.schedulerEnabled) {
                          return Row(children: [
                            Icon(Icons.stacked_line_chart_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Scheduled mode'),
                          ]);
                        } else {
                          return Row(children: [
                            Icon(Icons.bar_chart_outlined, size: 16),
                            SizedBox(width: 8),
                            Text('Manual mode'),
                          ]);
                        }
                      }),
                  Spacer(),
                  Selector<LyfiViewModel, ({DateTime? timestamp})>(
                    selector: (_, vm) =>
                        (timestamp: vm.borneoDeviceStatus?.timestamp),
                    builder: (context, vm, _) => Text(vm.timestamp != null
                        ? LyfiViewModel.deviceDateFormat.format(vm.timestamp!)
                        : 'N/A'),
                  ),
                ]),
              ),
              */
                    Expanded(
                      child: Container(
                        padding:
                            EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                        child: Selector<
                                LyfiViewModel,
                                ({
                                  bool schedulerEnabled,
                                  LedMode? mode,
                                  bool isOn
                                })>(
                            selector: (_, vm) => (
                                  schedulerEnabled: vm.schedulerEnabled,
                                  mode: vm.mode,
                                  isOn: vm.isOn,
                                ),
                            builder: (context, vm, _) {
                              Widget chart;
                              if (vm.mode == LedMode.nightlight) {
                                chart = ManualRunningChart();
                              } else if (vm.schedulerEnabled) {
                                chart = ScheduleRunningChart();
                              } else {
                                chart = ManualRunningChart();
                              }
                              return AnimatedSwitcher(
                                  duration: Duration(milliseconds: 300),
                                  transitionBuilder: (Widget child,
                                      Animation<double> animation) {
                                    return FadeTransition(
                                        opacity: animation, child: child);
                                  },
                                  child: chart);
                            }),
                      ),
                    ),
                  ]),
                ),
              ),
            ),
          ),

          // Power
          Selector<
              LyfiViewModel,
              ({
                bool isOnline,
                bool isOn,
                bool isBusy,
                bool isLocked,
                LedMode? mode,
                bool canSwitchNightlightMode,
                Duration nightlightRemaining,
              })>(
            selector: (_, vm) => (
              isOnline: vm.isOnline,
              isOn: vm.isOn,
              isBusy: vm.isBusy,
              isLocked: vm.isLocked,
              mode: vm.mode,
              canSwitchNightlightMode: vm.canSwitchNightlightMode,
              nightlightRemaining: vm.nightlightRemaining,
            ),
            builder: (context, vm, _) => Container(
              margin: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Row(mainAxisAlignment: MainAxisAlignment.end, children: [
                PowerSwitch(
                  value: vm.isOn,
                  onChanged: vm.isOnline && !vm.isBusy && vm.isLocked
                      ? (value) => context
                          .read<LyfiViewModel>()
                          .switchPowerOnOff(!vm.isOn)
                      : null,
                ),
                SizedBox(width: 8),
                Text(vm.isOn ? 'ON' : 'OFF',
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(color: Theme.of(context).hintColor)),
                Spacer(),
                // Settings button
                FilledButton.tonalIcon(
                  icon: vm.mode == LedMode.nightlight
                      ? SizedBox(
                          height: 16,
                          width: 16,
                          child: LinearProgressIndicator())
                      : Icon(Icons.nightlight_outlined),
                  label: vm.mode == LedMode.nightlight
                      ? Text(
                          'Night light off (${vm.nightlightRemaining.inSeconds})')
                      : Text('Night light'),
                  onPressed: vm.canSwitchNightlightMode
                      ? () {
                          context.read<LyfiViewModel>().switchNightlightMode();
                        }
                      : null,
                ),
              ]),
            ),
          ),

          // Measured power, Temp. and fan
          Expanded(
            child: GridView.count(
              childAspectRatio: 1.0,
              shrinkWrap: true,
              crossAxisCount: 2,
              crossAxisSpacing: 8.0,
              mainAxisSpacing: 8.0,
              padding: const EdgeInsets.all(16.0),
              children: [
                // Total Brightness
                Consumer<LyfiViewModel>(
                  builder: (context, vm, _) => MultiValueListenableBuilder<int>(
                    valueNotifiers: vm.channels,
                    builder: (context, values, _) => DashboardToufu(
                      title: 'Brightness',
                      icon: Icons.lightbulb_outline,
                      backgroundColor:
                          Theme.of(context).colorScheme.secondaryContainer,
                      foregroundColor:
                          Theme.of(context).colorScheme.onSecondaryContainer,
                      arcColor: Theme.of(context).colorScheme.outlineVariant,
                      progressColor: Theme.of(context).colorScheme.secondary,
                      value: vm.channels.isNotEmpty
                          ? vm.overallBrightness / vm.maxOverallBrightness
                          : 0.0,
                      center: Text(
                        vm.channels.isNotEmpty
                            ? '${(vm.overallBrightness / vm.maxOverallBrightness * 100).toStringAsFixed(1)}%'
                            : "N/A",
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context)
                              .colorScheme
                              .onSecondaryContainer,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ),
                ),

                // Total Power
                Consumer<LyfiViewModel>(
                  builder: (context, vm, _) => MultiValueListenableBuilder<int>(
                    valueNotifiers: vm.channels,
                    builder: (context, values, _) => DashboardToufu(
                      title: 'Power',
                      icon: Icons.power_outlined,
                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                      backgroundColor:
                          Theme.of(context).colorScheme.surfaceContainer,
                      arcColor: Theme.of(context).colorScheme.outlineVariant,
                      progressColor: Theme.of(context).colorScheme.tertiary,
                      value: vm.channels.isNotEmpty
                          ? vm.overallBrightness / vm.maxOverallBrightness
                          : 0,
                      center: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              vm.channels.isNotEmpty &&
                                      vm.borneoDeviceStatus?.powerVoltage !=
                                          null &&
                                      vm.borneoDeviceStatus?.powerCurrent !=
                                          null
                                  ? '${(vm.borneoDeviceStatus!.powerVoltage! * vm.borneoDeviceStatus!.powerCurrent!).toStringAsFixed(0)}W'
                                  : "N/A",
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                      color: Theme.of(context)
                                          .colorScheme
                                          .tertiary),
                            ),
                            Text(
                              vm.channels.isNotEmpty
                                  ? '${vm.borneoDeviceStatus?.powerVoltage?.toStringAsFixed(1) ?? ''}V/${vm.borneoDeviceStatus?.powerCurrent?.toStringAsFixed(1) ?? ''}A'
                                  : "N/A",
                              style: Theme.of(context)
                                  .textTheme
                                  .labelSmall
                                  ?.copyWith(
                                color: Theme.of(context)
                                    .colorScheme
                                    .onSurface
                                    .withAlpha(97),
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                          ]),
                    ),
                  ),
                ),

                // Temp.
                Selector<LyfiViewModel,
                    ({int? currentTemp, double currentTempRatio})>(
                  selector: (_, vm) => (
                    currentTemp: vm.currentTemp,
                    currentTempRatio: vm.currentTempRatio,
                  ),
                  builder: (context, vm, _) => DashboardToufu(
                    title: 'Temperature',
                    icon: Icons.thermostat,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainer,
                    arcColor: Theme.of(context).colorScheme.outlineVariant,
                    progressColor: Theme.of(context).colorScheme.secondary,
                    value: vm.currentTempRatio,
                    center: Text(
                      vm.currentTemp != null ? '${vm.currentTemp}℃' : "N/A",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),

                // Fan
                Selector<LyfiViewModel, ({double fanPowerRatio})>(
                  selector: (_, vm) => (fanPowerRatio: vm.fanPowerRatio),
                  builder: (context, vm, _) => DashboardToufu(
                    title: 'Fan',
                    icon: Icons.air,
                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                    backgroundColor:
                        Theme.of(context).colorScheme.surfaceContainer,
                    arcColor: Theme.of(context).colorScheme.outlineVariant,
                    progressColor: Theme.of(context).colorScheme.secondary,
                    value: vm.fanPowerRatio / 100.0,
                    center: Text(
                      '${vm.fanPowerRatio.toInt()}%',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: Theme.of(context).colorScheme.primary),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Temp. On button
          /*
      Consumer<LyfiViewModel>(
        builder: (context, vm, _) => Container(
          margin: EdgeInsets.fromLTRB(16, 16, 16, 0),
          child: ElevatedButton.icon(
            iconAlignment: IconAlignment.start,
            label: const Text("Temporary On"),
            icon: const Icon(Icons.lightbulb_outline),
            onPressed:
                !vm.isOnline || vm.isOn || vm.isBusy || !vm.schedulerEnabled
                    ? null
                    : () {},
          ),
        ),
      ),
      */

          // Unlock
          Builder(
            builder: (context) {
              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
                child: Selector<LyfiViewModel, bool>(
                  selector: (_, vm) => vm.canUnlock,
                  builder: (context, canUnlock, _) => SlideAction(
                    height: 64,
                    sliderRotate: false,
                    borderRadius: 8,
                    animationDuration: const Duration(milliseconds: 200),
                    outerColor: _desaturateColor(
                        Theme.of(context).colorScheme.primaryContainer, 0.5),
                    innerColor: Theme.of(context).colorScheme.inverseSurface,
                    key: key,
                    enabled: canUnlock,
                    sliderButtonIconPadding: 8,
                    onSubmit: () async =>
                        context.read<LyfiViewModel>().toggleLock(false),
                    alignment: Alignment.centerRight,
                    sliderButtonIcon: Icon(Icons.lock_outline,
                        size: 32,
                        color: canUnlock
                            ? Theme.of(context).colorScheme.onInverseSurface
                            : Theme.of(context).disabledColor),
                    submittedIcon: Icon(Icons.lock_open_outlined,
                        color: Theme.of(context).colorScheme.onInverseSurface,
                        size: 32),
                    textStyle: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                            color: canUnlock
                                ? Theme.of(context)
                                    .colorScheme
                                    .onPrimaryContainer
                                : Theme.of(context).disabledColor),
                    text: 'Unlock the dimming mode',
                  ),
                ),
              );
            },
          ),
        ]);
  }

  Color _desaturateColor(Color color, double factor) {
    final hslColor = HSLColor.fromColor(color);
    var newSaturation = hslColor.saturation * (1.0 - factor);
    newSaturation = newSaturation.clamp(0.0, 1.0);
    return hslColor.withSaturation(newSaturation).toColor();
  }
}
