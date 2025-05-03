import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/schedule_chart.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/settings_screen.dart';
import 'package:borneo_app/widgets/icon_progress.dart';
import 'package:borneo_app/widgets/power_switch.dart';
import 'package:borneo_app/widgets/rounded_icon_text_button.dart';
import 'package:borneo_app/widgets/value_listenable_builders.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:borneo_common/duration_ext.dart';

import 'package:borneo_app/views/common/hex_color.dart';
import '../view_models/lyfi_view_model.dart';
import 'color_chart.dart';

class ManualRunningChart extends StatelessWidget {
  const ManualRunningChart({super.key});

  List<BarChartGroupData> buildGroupDataItems(BuildContext context, LyfiViewModel vm) {
    int index = 0;
    return vm.lyfiDeviceInfo.channels.map((ch) {
      final channel = vm.channels[index];
      final g = makeGroupData(context, ch, index, channel.value.toDouble());
      index++;
      return g;
    }).toList();
  }

  BarChartGroupData makeGroupData(BuildContext context, LyfiChannelInfo ch, int x, double y) {
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
            toY: lyfiBrightnessMax.toDouble(),
            color: Theme.of(context).scaffoldBackgroundColor,
          ),
        ),
      ],
    );
  }

  Widget buildTitles(BuildContext context, LyfiViewModel vm, double value) {
    final index = value.toInt();
    final ch = vm.lyfiDeviceInfo.channels[index];
    return Text(
      ch.name,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final vm = context.read<LyfiViewModel>();
    if (vm.isOnline) {
      return Consumer<LyfiViewModel>(
        builder:
            (context, vm, _) => MultiValueListenableBuilder<int>(
              valueNotifiers: vm.channels,
              builder:
                  (context, values, _) => Padding(
                    padding: EdgeInsets.fromLTRB(24, 16, 24, 0),
                    child: LyfiColorChart(
                      BarChartData(
                        barGroups: buildGroupDataItems(context, vm),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
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
                  ),
            ),
      );
    } else {
      return Center(
        child: Text("Device Offline.", style: theme.textTheme.labelLarge?.copyWith(color: theme.colorScheme.error)),
      );
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
    final bgColor = backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer;
    final progColor = progressColor ?? Theme.of(context).colorScheme.primary;
    final arcColor = this.arcColor ?? Theme.of(context).colorScheme.onSurfaceVariant;
    return Card(
      margin: EdgeInsets.all(0),
      color: bgColor,
      elevation: 0,
      child: LayoutBuilder(
        builder:
            (context, constraints) => Stack(
              children: [
                if (icon != null)
                  Positioned(
                    bottom: -constraints.maxHeight * 0.15,
                    right: -constraints.maxWidth * 0.15,
                    child: Icon(icon!, size: constraints.maxWidth * 0.75, color: fgColor.withAlpha(8)),
                  ),
                Positioned.fill(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.all(0),
                            child: LayoutBuilder(
                              builder:
                                  (context, constraints) => CircularPercentIndicator(
                                    animationDuration: 300,
                                    radius: (constraints.maxHeight) / 2.5,
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
                                    footer: Text(title),
                                  ),
                            ),
                          ),
                        ),
                        //Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fgColor)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
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
          builder:
              (context, constraints) => AspectRatio(
                aspectRatio: 2.5,
                child: Container(
                  color: Theme.of(context).colorScheme.surfaceContainer,
                  child: Container(
                    color: Theme.of(context).colorScheme.surfaceContainer,
                    margin: EdgeInsets.all(0),
                    child: Column(
                      children: [
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
                            padding: EdgeInsets.symmetric(horizontal: 0, vertical: 16),
                            child: Stack(
                              children: [
                                Selector<LyfiViewModel, ({LedRunningMode mode, LedState? state, bool isOn})>(
                                  selector: (_, vm) => (mode: vm.mode, state: vm.ledState, isOn: vm.isOn),
                                  builder: (context, vm, _) {
                                    Widget chart;
                                    if (vm.state == LedState.nightlight) {
                                      chart = ManualRunningChart();
                                    } else if (vm.mode == LedRunningMode.manual) {
                                      chart = ManualRunningChart();
                                    } else {
                                      chart = ScheduleChart();
                                    }
                                    return AnimatedSwitcher(
                                      duration: Duration(milliseconds: 300),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(opacity: animation, child: child);
                                      },
                                      child: chart,
                                    );
                                  },
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
        ),

        // Measured power, Temp. and fan
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Total Brightness
                      Consumer<LyfiViewModel>(
                        builder:
                            (context, vm, _) => MultiValueListenableBuilder<int>(
                              valueNotifiers: vm.channels,
                              builder:
                                  (context, values, _) => Expanded(
                                    child: DashboardToufu(
                                      title: 'Brightness',
                                      icon: Icons.lightbulb_outline,
                                      backgroundColor: Theme.of(context).colorScheme.secondaryContainer,
                                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                      arcColor: Theme.of(context).colorScheme.outlineVariant,
                                      progressColor: Theme.of(context).colorScheme.secondary,
                                      value:
                                          vm.channels.isNotEmpty ? vm.overallBrightness / vm.maxOverallBrightness : 0.0,
                                      center: Text(
                                        vm.channels.isNotEmpty
                                            ? '${(vm.overallBrightness / vm.maxOverallBrightness * 100).toStringAsFixed(1)}%'
                                            : "N/A",
                                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                          color: Theme.of(context).colorScheme.onSecondaryContainer,
                                          fontFeatures: [FontFeature.tabularFigures()],
                                        ),
                                      ),
                                    ),
                                  ),
                            ),
                      ),

                      SizedBox(width: 8.0),
                      // Total Power
                      Consumer<LyfiViewModel>(
                        builder:
                            (context, vm, _) => MultiValueListenableBuilder<int>(
                              valueNotifiers: vm.channels,
                              builder:
                                  (context, values, _) => Expanded(
                                    child: DashboardToufu(
                                      title: 'Power',
                                      icon: Icons.power_outlined,
                                      foregroundColor: Theme.of(context).colorScheme.onSurface,
                                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                      arcColor: Theme.of(context).colorScheme.outlineVariant,
                                      progressColor: Theme.of(context).colorScheme.tertiary,
                                      value:
                                          vm.channels.isNotEmpty ? vm.overallBrightness / vm.maxOverallBrightness : 0,
                                      center: Column(
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        children: [
                                          Text(
                                            vm.channels.isNotEmpty &&
                                                    vm.borneoDeviceStatus?.powerVoltage != null &&
                                                    vm.borneoDeviceStatus?.powerCurrent != null
                                                ? '${(vm.borneoDeviceStatus!.powerVoltage! * vm.borneoDeviceStatus!.powerCurrent!).toStringAsFixed(0)}W'
                                                : "N/A",
                                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                              color: Theme.of(context).colorScheme.tertiary,
                                            ),
                                          ),
                                          Text(
                                            vm.channels.isNotEmpty
                                                ? '${vm.borneoDeviceStatus?.powerVoltage?.toStringAsFixed(1) ?? ''}V/${vm.borneoDeviceStatus?.powerCurrent?.toStringAsFixed(1) ?? ''}A'
                                                : "N/A",
                                            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                              color: Theme.of(context).colorScheme.onSurface.withAlpha(97),
                                              fontFeatures: [FontFeature.tabularFigures()],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                            ),
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 8.0),

                Expanded(
                  child: Row(
                    children: [
                      // Temp.
                      Selector<LyfiViewModel, ({int? currentTemp, double currentTempRatio})>(
                        selector: (_, vm) => (currentTemp: vm.currentTemp, currentTempRatio: vm.currentTempRatio),
                        builder:
                            (context, vm, _) => Expanded(
                              child: DashboardToufu(
                                title: 'Temperature',
                                icon: Icons.thermostat,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                arcColor: Theme.of(context).colorScheme.outlineVariant,
                                progressColor: Theme.of(context).colorScheme.secondary,
                                value: vm.currentTempRatio,
                                center: Text(
                                  vm.currentTemp != null ? '${vm.currentTemp}℃' : "N/A",
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontFeatures: [FontFeature.tabularFigures()],
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                      ),

                      SizedBox(width: 8.0),
                      // Fan
                      Selector<LyfiViewModel, ({double fanPowerRatio})>(
                        selector: (_, vm) => (fanPowerRatio: vm.fanPowerRatio),
                        builder:
                            (context, vm, _) => Expanded(
                              child: DashboardToufu(
                                title: 'Fan',
                                icon: Icons.air,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                arcColor: Theme.of(context).colorScheme.outlineVariant,
                                progressColor: Theme.of(context).colorScheme.secondary,
                                value: vm.fanPowerRatio / 100.0,
                                center: Text(
                                  '${vm.fanPowerRatio.toInt()}%',
                                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                    fontFeatures: [FontFeature.tabularFigures()],
                                    color: Theme.of(context).colorScheme.primary,
                                  ),
                                ),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        // Power
        Selector<
          LyfiViewModel,
          ({
            bool isOnline,
            bool isOn,
            bool isBusy,
            bool isLocked,
            LedState? ledState,
            bool canSwitchNightlightState,
            Duration nightlightRemaining,
          })
        >(
          selector:
              (_, vm) => (
                isOnline: vm.isOnline,
                isOn: vm.isOn,
                isBusy: vm.isBusy,
                isLocked: vm.isLocked,
                ledState: vm.ledState,
                canSwitchNightlightState: vm.canSwitchNightlightState,
                nightlightRemaining: vm.nightlightRemaining,
              ),
          builder:
              (context, vm, _) => Container(
                margin: const EdgeInsets.fromLTRB(0, 24, 0, 0),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: PowerButton(
                              value: vm.isOn,
                              label: Text(
                                vm.isOn ? 'ON' : 'OFF',
                                style: Theme.of(
                                  context,
                                ).textTheme.titleSmall?.copyWith(color: Theme.of(context).hintColor),
                              ),
                              onChanged:
                                  vm.isOnline && !vm.isBusy && vm.isLocked
                                      ? (value) => context.read<LyfiViewModel>().switchPowerOnOff(!vm.isOn)
                                      : null,
                            ),
                          ),

                          Expanded(
                            child: RoundedIconTextButton(
                              borderColor: Theme.of(context).colorScheme.primary,
                              text:
                                  vm.ledState == LedState.nightlight
                                      ? 'Temporary (${vm.nightlightRemaining.inSeconds})'
                                      : 'Temporary',
                              buttonSize: 64,
                              icon:
                                  vm.ledState == LedState.nightlight
                                      ? IconProgressBar(
                                        icon: Icon(Icons.flashlight_on, size: 40),
                                        progress: 0.5,
                                        size: 40,
                                        progressColor: Theme.of(context).colorScheme.primary,
                                        backgroundColor: Theme.of(context).colorScheme.primaryFixedDim,
                                      )
                                      : Icon(Icons.flashlight_off, size: 40),

                              onPressed:
                                  vm.canSwitchNightlightState
                                      ? () => context.read<LyfiViewModel>().switchNightlightState()
                                      : null,
                            ),
                          ),

                          Selector<LyfiViewModel, bool>(
                            selector: (_, vm) => vm.canUnlock,
                            builder:
                                (context, canUnlock, _) => Expanded(
                                  child: RoundedIconTextButton(
                                    borderColor: Theme.of(context).colorScheme.primary,
                                    text: "Dimming",
                                    buttonSize: 64,
                                    icon: Icon(Icons.tips_and_updates_outlined, size: 40),
                                    onPressed:
                                        canUnlock ? () async => context.read<LyfiViewModel>().toggleLock(false) : null,
                                  ),
                                ),
                          ),
                        ],
                      ),

                      //sep
                      SizedBox(height: 16),

                      // next row
                      Row(
                        children: [
                          Expanded(
                            child: RoundedIconTextButton(
                              borderColor: Theme.of(context).colorScheme.primary,
                              text: "Moon",
                              buttonSize: 64,
                              icon: Icon(Icons.nightlight_outlined, size: 40),
                              onPressed: null,
                            ),
                          ),

                          // Settings button
                          Expanded(
                            child: RoundedIconTextButton(
                              borderColor: Theme.of(context).colorScheme.primary,
                              text: "Acclimation",
                              buttonSize: 64,
                              icon: Icon(Icons.calendar_month_outlined, size: 40),
                              onPressed: null,
                            ),
                          ),

                          Expanded(
                            child: RoundedIconTextButton(
                              borderColor: Theme.of(context).colorScheme.primary,
                              text: "Settings",
                              buttonSize: 64,
                              icon: Icon(Icons.settings_outlined, size: 40),
                              onPressed: () async {
                                final lyfi = context.read<LyfiViewModel>();
                                final vm = await lyfi.loadSettings();
                                await Future.delayed(Duration(milliseconds: 200));
                                final route = MaterialPageRoute(builder: (context) => SettingsScreen(vm));
                                if (context.mounted) {
                                  lyfi.stopTimer();
                                  try {
                                    await Navigator.push(context, route);
                                  } finally {
                                    lyfi.startTimer();
                                  }
                                }
                              },
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
        ),

        // Unlock
        /*
        Builder(
          builder: (context) {
            return Padding(
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
              child: Selector<LyfiViewModel, bool>(
                selector: (_, vm) => vm.canUnlock,
                builder:
                    (context, canUnlock, _) => SlideAction(
                      height: 64,
                      sliderRotate: false,
                      borderRadius: 8,
                      animationDuration: const Duration(milliseconds: 200),
                      outerColor: _desaturateColor(Theme.of(context).colorScheme.primaryContainer, 0.5),
                      innerColor: Theme.of(context).colorScheme.inverseSurface,
                      key: key,
                      enabled: canUnlock,
                      sliderButtonIconPadding: 8,
                      onSubmit: () async => context.read<LyfiViewModel>().toggleLock(false),
                      alignment: Alignment.centerRight,
                      sliderButtonIcon: Icon(
                        Icons.lock_outline,
                        size: 32,
                        color:
                            canUnlock
                                ? Theme.of(context).colorScheme.onInverseSurface
                                : Theme.of(context).disabledColor,
                      ),
                      submittedIcon: Icon(
                        Icons.lock_open_outlined,
                        color: Theme.of(context).colorScheme.onInverseSurface,
                        size: 32,
                      ),
                      textStyle: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color:
                            canUnlock
                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                : Theme.of(context).disabledColor,
                      ),
                      text: 'Unlock dimming mode',
                    ),
              ),
            );
          },
        ),
        */
      ],
    );
  }

  Color _desaturateColor(Color color, double factor) {
    final hslColor = HSLColor.fromColor(color);
    var newSaturation = hslColor.saturation * (1.0 - factor);
    newSaturation = newSaturation.clamp(0.0, 1.0);
    return hslColor.withSaturation(newSaturation).toColor();
  }
}
