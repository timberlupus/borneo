import 'package:borneo_app/devices/borneo/lyfi/view_models/acclimation_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/acclimation_screen.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/lyfi_view.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/schedule_chart.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/settings_screen.dart';
import 'package:borneo_app/widgets/icon_progress.dart';
import 'package:borneo_app/widgets/power_switch.dart';
import 'package:borneo_app/widgets/rounded_icon_text_button.dart';
import 'package:borneo_app/widgets/value_listenable_builders.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:gauge_indicator/gauge_indicator.dart';
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
  final double maxValue;
  final double minValue;
  final IconData? icon;
  final Widget? center;
  final Color? backgroundColor;
  final Color? foregroundColor;
  final Color? progressColor;
  final Color? arcColor;
  final List<GaugeSegment> segments;

  const DashboardToufu({
    required this.title,
    required this.value,
    required this.center,
    required this.minValue,
    required this.maxValue,
    this.icon,
    this.backgroundColor,
    this.foregroundColor,
    this.progressColor,
    this.arcColor,
    this.segments = const [],
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    final fgColor = foregroundColor ?? Theme.of(context).colorScheme.onSurface ?? Colors.black;
    final bgColor = backgroundColor ?? Theme.of(context).colorScheme.surfaceContainer ?? Colors.grey[200]!;
    final progColor = progressColor ?? Theme.of(context).colorScheme.primary ?? Colors.blue;
    final arcColor = this.arcColor ?? Theme.of(context).colorScheme.onSurfaceVariant ?? Colors.grey;

    assert(!minValue.isNaN);
    assert(!maxValue.isNaN);
    assert(!value.isNaN);

    return Card(
      margin: const EdgeInsets.all(0),
      color: bgColor,
      elevation: 0,
      child: SizedBox(
        height: 200, // Provide bounded height
        child: LayoutBuilder(
          builder:
              (context, constraints) => Padding(
                padding: const EdgeInsets.fromLTRB(8, 16, 8, 8),
                child: Stack(
                  clipBehavior: Clip.hardEdge, // Prevent overflow
                  children: [
                    if (icon != null)
                      Positioned(
                        bottom: -constraints.maxHeight * 0.2,
                        right: -constraints.maxWidth * 0.2,
                        child: ClipRect(
                          child: Icon(icon!, size: constraints.maxWidth * 0.75, color: fgColor.withAlpha(8)),
                        ),
                      ),
                    Positioned.fill(
                      child: Column(
                        mainAxisSize: MainAxisSize.max,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Expanded(
                            child: AnimatedRadialGauge(
                              initialValue: minValue.roundToDouble(),
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.decelerate,
                              value: value.roundToDouble(),
                              radius: null,
                              axis: GaugeAxis(
                                min: minValue.roundToDouble(),
                                max: maxValue.roundToDouble(),
                                degrees: 270,
                                style: GaugeAxisStyle(
                                  thickness: 13,
                                  segmentSpacing: 0,
                                  background: segments.isEmpty ? arcColor : null,
                                  cornerRadius: Radius.zero,
                                ),
                                pointer: null,
                                progressBar: GaugeProgressBar.basic(color: progColor),
                                segments: segments,
                              ),
                              builder: (context, label, value) => Center(child: label),
                              child: center,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: fgColor)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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

        // Toufu blocks
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Consumer<LyfiViewModel>(
                          builder:
                              (context, vm, _) => MultiValueListenableBuilder<int>(
                                valueNotifiers: vm.channels,
                                builder:
                                    (context, values, _) => DashboardToufu(
                                      title: 'Brightness',
                                      icon: Icons.lightbulb_outline,
                                      backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                      foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                      arcColor: Theme.of(context).colorScheme.outlineVariant,
                                      progressColor: Theme.of(context).colorScheme.secondary,
                                      minValue: 0,
                                      maxValue: vm.maxOverallBrightness,
                                      value: vm.channels.isNotEmpty ? vm.overallBrightness : 0.0,
                                      center: Row(
                                        crossAxisAlignment: CrossAxisAlignment.baseline,
                                        mainAxisAlignment: MainAxisAlignment.center,
                                        textBaseline: TextBaseline.alphabetic,
                                        children: [
                                          Text(
                                            vm.channels.isNotEmpty
                                                ? (vm.overallBrightness / vm.maxOverallBrightness * 100)
                                                    .toStringAsFixed(0)
                                                : "N/A",
                                            style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                              fontFeatures: [FontFeature.tabularFigures()],
                                              color: Theme.of(context).colorScheme.primary,
                                              fontSize: 24,
                                            ),
                                          ),
                                          if (vm.channels.isNotEmpty)
                                            Text(
                                              '%',
                                              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                fontFeatures: [FontFeature.tabularFigures()],
                                                color: Theme.of(context).colorScheme.primary,
                                                fontSize: 12,
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                              ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Consumer<LyfiViewModel>(
                          builder:
                              (context, vm, _) => MultiValueListenableBuilder<int>(
                                valueNotifiers: vm.channels,
                                builder: (context, values, _) {
                                  return DashboardToufu(
                                    title: 'Power',
                                    icon: Icons.power_outlined,
                                    foregroundColor: Theme.of(context).colorScheme.onSurface,
                                    backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                    arcColor: Theme.of(context).colorScheme.outlineVariant,
                                    progressColor: Theme.of(context).colorScheme.tertiary,
                                    minValue: 0.0,
                                    maxValue: vm.lyfiDeviceInfo.nominalPower ?? 9999,
                                    value: vm.currentWatts,
                                    center: Column(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      mainAxisSize: MainAxisSize.max,
                                      crossAxisAlignment: CrossAxisAlignment.center,
                                      children: [
                                        Row(
                                          crossAxisAlignment: CrossAxisAlignment.baseline,
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          textBaseline: TextBaseline.alphabetic,
                                          children: [
                                            Text(
                                              vm.canMeasurePower ? vm.currentWatts.toStringAsFixed(0) : "N/A",
                                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                                color: Theme.of(context).colorScheme.primary,
                                                fontFeatures: [FontFeature.tabularFigures()],
                                                fontSize: 23,
                                              ),
                                            ),
                                            if (vm.borneoDeviceStatus?.powerVoltage != null &&
                                                vm.borneoDeviceStatus?.powerCurrent != null)
                                              Text(
                                                'W',
                                                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                  color: Theme.of(context).colorScheme.primary,
                                                  fontSize: 11,
                                                ),
                                              ),
                                          ],
                                        ),
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.center,
                                          children: [
                                            if (vm.borneoDeviceStatus?.powerVoltage != null)
                                              Text(
                                                '${vm.borneoDeviceStatus!.powerVoltage!.toStringAsFixed(0)}V',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            if (vm.borneoDeviceStatus?.powerCurrent != null) SizedBox(width: 4),
                                            if (vm.borneoDeviceStatus?.powerCurrent != null)
                                              Text(
                                                '${vm.borneoDeviceStatus!.powerCurrent!.toStringAsFixed(0)}A',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Selector<LyfiViewModel, ({int? currentTemp, double currentTempRatio})>(
                          selector: (_, vm) => (currentTemp: vm.currentTemp, currentTempRatio: vm.currentTempRatio),
                          builder:
                              (context, vm, _) => DashboardToufu(
                                title: 'Temperature',
                                icon: Icons.thermostat,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                arcColor: null,
                                progressColor: switch (vm.currentTemp) {
                                  != null && <= 45 => Theme.of(context).primaryColor,
                                  != null && > 45 && < 65 => Theme.of(context).colorScheme.secondary,
                                  != null && >= 65 => Theme.of(context).colorScheme.error,
                                  null || int() => Colors.grey,
                                },
                                value: vm.currentTemp?.toDouble() ?? 0.0,
                                minValue: 0,
                                maxValue: 105,
                                center: Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      vm.currentTemp != null ? '${vm.currentTemp}' : "N/A",
                                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                        fontFeatures: [FontFeature.tabularFigures()],
                                        color: Theme.of(context).colorScheme.primary,
                                        fontSize: 24,
                                      ),
                                    ),
                                    if (vm.currentTemp != null)
                                      Text(
                                        '℃',
                                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                                          fontFeatures: [FontFeature.tabularFigures()],
                                          color: Theme.of(context).colorScheme.primary,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                                segments: [
                                  GaugeSegment(from: 0, to: 45, color: Colors.green[100]!),
                                  GaugeSegment(from: 45, to: 65, color: Colors.orange[100]!),
                                  GaugeSegment(from: 65, to: 105, color: Colors.red[100]!),
                                ],
                              ),
                        ),
                      ),

                      const SizedBox(width: 16),

                      Expanded(
                        child: Selector<LyfiViewModel, ({double fanPowerRatio})>(
                          selector: (_, vm) => (fanPowerRatio: vm.fanPowerRatio),
                          builder:
                              (context, vm, _) => DashboardToufu(
                                title: 'Fan',
                                icon: Icons.air,
                                foregroundColor: Theme.of(context).colorScheme.onSurface,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                arcColor: Theme.of(context).colorScheme.outlineVariant,
                                progressColor: Theme.of(context).colorScheme.secondary,
                                minValue: 0,
                                maxValue: 100,
                                value: vm.fanPowerRatio,
                                center: Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      '${vm.fanPowerRatio.toInt()}',
                                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                                        fontFeatures: [FontFeature.tabularFigures()],
                                        fontSize: 24,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                    Text(
                                      '%',
                                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                        fontFeatures: [FontFeature.tabularFigures()],
                                        fontSize: 12,
                                        color: Theme.of(context).colorScheme.primary,
                                      ),
                                    ),
                                  ],
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

        // Icon buttons
        Container(
          margin: const EdgeInsets.fromLTRB(0, 24, 0, 0),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          child: Container(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _buildIconButtonsRow(
                  children: [
                    Selector<LyfiViewModel, ({bool isOn, bool isOnline, bool isBusy, bool isLocked})>(
                      selector:
                          (_, vm) => (isOn: vm.isOn, isOnline: vm.isOnline, isBusy: vm.isBusy, isLocked: vm.isLocked),
                      builder:
                          (context, props, _) => PowerButton(
                            value: props.isOn,
                            label: Text(
                              props.isOn ? 'ON' : 'OFF',
                              style: Theme.of(
                                context,
                              ).textTheme.titleSmall?.copyWith(color: Theme.of(context).hintColor),
                            ),
                            onChanged:
                                props.isOnline && !props.isBusy && props.isLocked
                                    ? (value) => context.read<LyfiViewModel>().switchPowerOnOff(!props.isOn)
                                    : null,
                          ),
                    ),

                    // Dimming button
                    Selector<LyfiViewModel, bool>(
                      selector: (_, vm) => vm.canUnlock,
                      builder:
                          (context, canUnlock, _) => RoundedIconTextButton(
                            borderColor: Theme.of(context).colorScheme.primary,
                            text: "Dimming",
                            buttonSize: 64,
                            icon: Icon(Icons.tips_and_updates_outlined, size: 40),
                            onPressed: canUnlock ? () async => context.read<LyfiViewModel>().toggleLock(false) : null,
                          ),
                    ),

                    // Temporary button
                    Selector<LyfiViewModel, ({LedState? state, bool canSwitch})>(
                      selector: (_, vm) => (state: vm.ledState, canSwitch: vm.canSwitchNightlightState),
                      builder:
                          (context, props, _) => RoundedIconTextButton(
                            borderColor: Theme.of(context).colorScheme.primary,
                            text: 'Temporary',
                            buttonSize: 64,
                            backgroundColor:
                                props.state == LedState.nightlight
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : null,
                            icon: AnimatedSwitcher(
                              duration: Duration(milliseconds: 500),
                              child:
                                  props.state == LedState.nightlight
                                      ? IconProgressBar(
                                        icon: Icon(Icons.flashlight_on, size: 40),
                                        progress: 0.5,
                                        size: 40,
                                        progressColor:
                                            props.state == LedState.nightlight
                                                ? Theme.of(context).colorScheme.inversePrimary
                                                : Theme.of(context).colorScheme.primary,
                                        backgroundColor:
                                            props.state == LedState.nightlight
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.primaryContainer,
                                      )
                                      : Icon(Icons.flashlight_on, size: 40),
                            ),

                            onPressed:
                                props.canSwitch ? () => context.read<LyfiViewModel>().switchNightlightState() : null,
                          ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),
                _buildIconButtonsRow(
                  children: [
                    // Moon button
                    RoundedIconTextButton(
                      borderColor: Theme.of(context).colorScheme.primary,
                      text: "Moon",
                      buttonSize: 64,
                      icon: const Icon(Icons.nightlight_outlined, size: 40),
                      onPressed: null,
                    ),

                    // Acclimation button
                    Selector<LyfiViewModel, ({bool canGo, bool enabled, bool activated})>(
                      selector:
                          (_, vm) => (
                            canGo: vm.canLockOrUnlock,
                            enabled: vm.lyfiDeviceStatus?.acclimationEnabled ?? false,
                            activated: vm.lyfiDeviceStatus?.acclimationActivated ?? false,
                          ),
                      builder:
                          (context, props, _) => RoundedIconTextButton(
                            borderColor: Theme.of(context).colorScheme.primary,
                            text: "Acclimation",
                            buttonSize: 64,
                            icon: Icon(
                              Icons.calendar_month_outlined,
                              size: 40,
                              color:
                                  props.enabled || props.activated
                                      ? Theme.of(context).colorScheme.onPrimaryContainer
                                      : Theme.of(context).colorScheme.primary,
                            ),
                            backgroundColor:
                                props.enabled || props.activated
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : null,
                            onPressed:
                                props.canGo
                                    ? () async {
                                      if (context.mounted) {
                                        final vm = Provider.of<LyfiViewModel>(context, listen: false);
                                        final route = MaterialPageRoute(
                                          builder: (context) => AcclimationScreen(deviceID: vm.deviceID),
                                        );
                                        try {
                                          vm.stopTimer();
                                          await Navigator.push(context, route);
                                        } finally {
                                          vm.startTimer();
                                        }
                                      }
                                    }
                                    : null,
                          ),
                    ),

                    // Settings button
                    Selector<LyfiViewModel, ({bool isOnline, bool enabled, bool activated})>(
                      selector:
                          (_, vm) => (
                            isOnline: vm.isOnline,
                            enabled: vm.lyfiDeviceStatus?.acclimationEnabled ?? false,
                            activated: vm.lyfiDeviceStatus?.acclimationActivated ?? false,
                          ),
                      builder:
                          (context, props, _) => RoundedIconTextButton(
                            borderColor: Theme.of(context).colorScheme.primary,
                            text: "Settings",
                            buttonSize: 64,
                            icon: Icon(Icons.settings_outlined, size: 40),
                            onPressed:
                                props.isOnline
                                    ? () async {
                                      final lyfi = context.read<LyfiViewModel>();
                                      final vm = await lyfi.loadSettings();
                                      final route = MaterialPageRoute(builder: (context) => SettingsScreen(vm));
                                      if (context.mounted) {
                                        lyfi.stopTimer();
                                        try {
                                          await Navigator.push(context, route);
                                        } finally {
                                          lyfi.startTimer();
                                        }
                                      }
                                    }
                                    : null,
                          ),
                    ),
                  ],
                ),

                /*
                Row(
                  children: [
                    Expanded(
                      child: 
                      child: Container(),
                    ),

                    Expanded(
                      child: 
                    ),

                    Expanded(
                      child: 
                      
                    ),
                  ],
                ),

                //sep

                // next row
                Row(
                  children: [
                    Expanded(
                      child:
                    ),

                    // Settings button
                    Expanded(
                      child:
               
                    ),

                    Expanded(
                      child: 

                    ),
                  ],
                ),
                */
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildIconButtonsRow({required List<Widget> children}) {
    return Row(
      children:
          children.map((child) {
            return Expanded(child: Center(child: child));
          }).toList(),
    );
  }

  Widget _buildToufuRow({required List<Widget> children}) {
    return Row(
      mainAxisSize: MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        for (int i = 0; i < children.length; i++) ...[
          Flexible(flex: 1, child: children[i]),
          if (i != children.length - 1) const SizedBox(width: 16),
        ],
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
