import 'package:borneo_app/devices/borneo/lyfi/view_models/constants.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/acclimation_screen.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/widgets/manual_running_chart.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/schedule_chart.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/widgets/schedule_running_chart.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/settings_screen.dart';
import 'package:borneo_app/widgets/icon_progress.dart';
import 'package:borneo_app/widgets/power_switch.dart';
import 'package:borneo_app/widgets/rounded_icon_text_button.dart';
import 'package:borneo_app/widgets/value_listenable_builders.dart';
import 'package:borneo_common/exceptions.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/material.dart';

import 'package:fl_chart/fl_chart.dart';
import 'package:gauge_indicator/gauge_indicator.dart';
import 'package:provider/provider.dart';
import 'package:borneo_common/duration_ext.dart';

import 'package:borneo_app/views/common/hex_color.dart';
import '../../view_models/lyfi_view_model.dart';
import '../color_chart.dart';

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
                                    Widget chart = switch (vm.mode) {
                                      LedRunningMode.manual => ManualRunningChart(),
                                      LedRunningMode.scheduled => ScheduleRunningChart(),
                                      LedRunningMode.sun => ScheduleRunningChart(),
                                      _ => throw InvalidDataException(message: 'Invalid LED running mode: $vm.mode'),
                                    };
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
                              (context, vm, _) => DashboardToufu(
                                title: 'Brightness',
                                icon: Icons.lightbulb_outline,
                                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                                foregroundColor: Theme.of(context).colorScheme.onSecondaryContainer,
                                arcColor: Theme.of(context).colorScheme.outlineVariant,
                                progressColor: Theme.of(context).colorScheme.secondary,
                                minValue: 0,
                                maxValue: 100,
                                value: vm.overallBrightness * 100.0,
                                center: Row(
                                  crossAxisAlignment: CrossAxisAlignment.baseline,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  textBaseline: TextBaseline.alphabetic,
                                  children: [
                                    Text(
                                      vm.channels.isNotEmpty
                                          ? (vm.overallBrightness * 100.0).toStringAsFixed(0)
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
                                    maxValue: vm.isOnline ? vm.lyfiDeviceInfo.nominalPower ?? 9999 : 9999,
                                    value: vm.isOn && vm.isOnline ? vm.currentWatts : 0,
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
                                            if (vm.canMeasurePower)
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
                                            if (vm.canMeasureVoltage)
                                              Text(
                                                '${vm.borneoDeviceStatus!.powerVoltage!.toStringAsFixed(1)}V',
                                                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                                                  color: Theme.of(context).colorScheme.onSurface,
                                                  fontFeatures: [FontFeature.tabularFigures()],
                                                ),
                                              ),
                                            if (vm.canMeasureCurrent) SizedBox(width: 4),
                                            if (vm.canMeasureCurrent)
                                              Text(
                                                '${vm.borneoDeviceStatus!.powerCurrent!.toStringAsFixed(1)}A',
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
                            enabled: props.isOnline,
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
                    Selector<LyfiViewModel, ({LedState? state, bool canSwitch, Duration total, Duration remain})>(
                      selector:
                          (context, vm) => (
                            state: vm.ledState,
                            canSwitch: vm.canSwitchTemporaryState,
                            total: vm.temporaryDuration,
                            remain: vm.temporaryRemaining.value,
                          ),
                      builder:
                          (context, props, _) => RoundedIconTextButton(
                            borderColor: Theme.of(context).colorScheme.primary,
                            text: 'Temporary',
                            buttonSize: 64,
                            backgroundColor:
                                props.state == LedState.temporary
                                    ? Theme.of(context).colorScheme.primaryContainer
                                    : null,
                            icon: AnimatedSwitcher(
                              duration: Duration(milliseconds: 500),
                              child:
                                  props.state == LedState.temporary
                                      ? IconProgressBar(
                                        icon: Icon(Icons.flashlight_on, size: 40),
                                        progress:
                                            (props.total.inSeconds - props.remain.inSeconds) / props.total.inSeconds,
                                        size: 40,
                                        progressColor:
                                            props.state == LedState.temporary
                                                ? Theme.of(context).colorScheme.inversePrimary
                                                : Theme.of(context).colorScheme.primary,
                                        backgroundColor:
                                            props.state == LedState.temporary
                                                ? Theme.of(context).colorScheme.onPrimaryContainer
                                                : Theme.of(context).colorScheme.primaryContainer,
                                      )
                                      : Icon(Icons.flashlight_on, size: 40),
                            ),

                            onPressed:
                                props.canSwitch ? () => context.read<LyfiViewModel>().switchTemporaryState() : null,
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
                                  props.canGo
                                      ? props.enabled || props.activated
                                          ? Theme.of(context).colorScheme.onPrimaryContainer
                                          : Theme.of(context).colorScheme.primary
                                      : null,
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

  /*
  Color _desaturateColor(Color color, double factor) {
    final hslColor = HSLColor.fromColor(color);
    var newSaturation = hslColor.saturation * (1.0 - factor);
    newSaturation = newSaturation.clamp(0.0, 1.0);
    return hslColor.withSaturation(newSaturation).toColor();
  }
  */
}
