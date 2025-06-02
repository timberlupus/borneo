import 'package:borneo_app/devices/borneo/lyfi/views/acclimation_screen.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/widgets/manual_running_chart.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/widgets/schedule_running_chart.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/settings_screen.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/widgets/sun_running_chart.dart';
import 'package:borneo_app/widgets/icon_progress.dart';
import 'package:borneo_app/widgets/power_switch.dart';
import 'package:borneo_app/widgets/rounded_icon_text_button.dart';
import 'package:borneo_app/widgets/value_listenable_builders.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import 'package:gauge_indicator/gauge_indicator.dart';
import 'package:provider/provider.dart';

import '../../view_models/lyfi_view_model.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.read<LyfiViewModel>().isOnline;
    if (!isOnline) {
      return const SizedBox.shrink();
    }
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
                                Selector<
                                  LyfiViewModel,
                                  ({bool isOnline, LedRunningMode mode, LedState? state, bool isOn})
                                >(
                                  selector:
                                      (_, vm) => (
                                        isOnline: vm.isOnline,
                                        mode: vm.mode,
                                        state: vm.ledState,
                                        isOn: vm.isOn,
                                      ),
                                  builder: (context, props, _) {
                                    if (!props.isOnline) {
                                      return const SizedBox.shrink();
                                    }
                                    final Widget widget = switch (props.mode) {
                                      LedRunningMode.manual => ManualRunningChart(),
                                      LedRunningMode.scheduled => ScheduleRunningChart(),
                                      LedRunningMode.sun => Selector<
                                        LyfiViewModel,
                                        ({List<LyfiChannelInfo> channels, List<ScheduledInstant> instants})
                                      >(
                                        selector:
                                            (context, vm) => (
                                              channels: vm.lyfiDeviceInfo.channels,
                                              instants: vm.sunInstants,
                                            ),
                                        builder:
                                            (context, selected, _) => SunRunningChart(
                                              sunInstants: selected.instants,
                                              channelInfoList: selected.channels,
                                            ),
                                      ),
                                    };

                                    return AnimatedSwitcher(
                                      duration: Duration(milliseconds: 300),
                                      transitionBuilder: (Widget child, Animation<double> animation) {
                                        return FadeTransition(opacity: animation, child: child);
                                      },
                                      child: widget,
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

        // 豆腐块区域，滚动列表
        Expanded(
          child: Padding(
            padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // 第一行：两个半高长方形豆腐块
                  Row(
                    children: [
                      Expanded(flex: 1, child: _powerSwitchTile()),
                      SizedBox(width: 16),
                      Expanded(flex: 1, child: _temporaryTile()),
                    ],
                  ),
                  SizedBox(height: 16),
                  // 后续全高正方形豆腐块
                  Row(
                    children: [Expanded(child: _PowerTile()), SizedBox(width: 16), Expanded(child: _TemperatureTile())],
                  ),
                  SizedBox(height: 16),
                  Row(children: [Expanded(child: _FanTile()), SizedBox(width: 16), Expanded(child: _DimmingTile())]),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: _AcclimationTile()),
                      SizedBox(width: 16),
                      Expanded(child: _SettingsTile()),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _powerSwitchTile() {
    return Selector<LyfiViewModel, ({bool isOn, bool isBusy, bool isLocked, double overallBrightness, bool canUnlock})>(
      selector:
          (_, vm) => (
            isOn: vm.isOn,
            isBusy: vm.isBusy,
            isLocked: vm.isLocked,
            overallBrightness: vm.overallBrightness,
            canUnlock: vm.canUnlock,
          ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isOn = props.isOn;
        final brightness = (props.overallBrightness * 100).clamp(0, 100).toInt();
        return AspectRatio(
          aspectRatio: 2.0,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap:
                  (!props.isBusy && props.isLocked)
                      ? () => context.read<LyfiViewModel>().switchPowerOnOff(!isOn)
                      : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: Row(
                    key: ValueKey(isOn),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左侧：开启时为亮度指示器，关闭时为红色电源图标，尺寸一致
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        child: isOn
                            ? Container(
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: theme.colorScheme.secondary,
                                ),
                              )
                            : Icon(Icons.power_settings_new, size: 20, color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      // 中间圆形亮度进度（仅开启时显示）
                      if (isOn)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                value: brightness / 100.0,
                                strokeWidth: 5,
                                backgroundColor: theme.colorScheme.outlineVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      if (isOn) const SizedBox(width: 16),
                      // 右侧双行文字
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOn ? 'ON' : 'OFF',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isOn)
                              Text(
                                '$brightness%',
                                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _temporaryTile() {
    return Selector<LyfiViewModel, ({LedState? state, bool canSwitch, Duration total, Duration remain})>(
      selector:
          (context, vm) => (
            state: vm.ledState,
            canSwitch: vm.canSwitchTemporaryState,
            total: vm.temporaryDuration,
            remain: vm.temporaryRemaining.value,
          ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isActive = props.state == LedState.temporary;
        final remainSeconds = props.remain.inSeconds;
        String remainText = '';
        if (isActive && props.total.inSeconds > 0) {
          final min = (remainSeconds ~/ 60).toString().padLeft(2, '0');
          final sec = (remainSeconds % 60).toString().padLeft(2, '0');
          remainText = '$min:$sec';
        }
        return AspectRatio(
          aspectRatio: 2.1, // 半高长方形
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: props.canSwitch ? () => context.read<LyfiViewModel>().switchTemporaryState() : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: Row(
                    key: ValueKey(isActive.toString() + remainText),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // 左侧图标
                      Container(
                        width: 32,
                        height: 32,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: isActive ? theme.colorScheme.primary : theme.colorScheme.outlineVariant,
                        ),
                        child: Icon(
                          Icons.flashlight_on,
                          size: 20,
                          color: isActive ? theme.colorScheme.onPrimary : theme.colorScheme.primary,
                        ),
                      ),
                      const SizedBox(width: 16),
                      // 右侧 Temporary 文字和剩余时间
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temporary',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: isActive ? theme.colorScheme.primary : theme.colorScheme.onSurface,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isActive && remainText.isNotEmpty)
                              Text(
                                remainText,
                                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _PowerTile() {
    return Consumer<LyfiViewModel>(
      builder:
          (context, vm, _) => DashboardToufu(
            title: 'Power',
            icon: Icons.power_outlined,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            arcColor: Theme.of(context).colorScheme.outlineVariant,
            progressColor: Theme.of(context).colorScheme.tertiary,
            minValue: 0.0,
            maxValue: vm.lyfiDeviceInfo.nominalPower ?? 9999,
            value: vm.isOn ? vm.currentWatts : 0,
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
          ),
    );
  }

  Widget _TemperatureTile() {
    return Selector<LyfiViewModel, ({int? currentTemp, double currentTempRatio})>(
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
    );
  }

  Widget _FanTile() {
    return Selector<LyfiViewModel, ({double fanPowerRatio})>(
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
    );
  }

  Widget _DimmingTile() {
    return Selector<LyfiViewModel, bool>(
      selector: (_, vm) => vm.canUnlock,
      builder: (context, canUnlock, _) {
        final theme = Theme.of(context);
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: canUnlock ? () async => context.read<LyfiViewModel>().toggleLock(false) : null,
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tips_and_updates_outlined, size: 40, color: theme.colorScheme.primary),
                    SizedBox(height: 8),
                    Text('Dimming', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _AcclimationTile() {
    return Selector<LyfiViewModel, ({bool canGo, bool enabled, bool activated})>(
      selector:
          (_, vm) => (
            canGo: vm.canLockOrUnlock,
            enabled: vm.lyfiDeviceStatus.acclimationEnabled,
            activated: vm.lyfiDeviceStatus.acclimationActivated,
          ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isActive = props.enabled || props.activated;
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap:
                  props.canGo
                      ? () async {
                        if (context.mounted) {
                          final vm = context.read<LyfiViewModel>();
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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_outlined,
                      size: 40,
                      color: isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary,
                    ),
                    SizedBox(height: 8),
                    Text('Acclimation', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _SettingsTile() {
    return Builder(
      builder: (context) {
        final theme = Theme.of(context);
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () async {
                final lyfi = context.read<LyfiViewModel>();
                final vm = await lyfi.loadSettings();
                final route = MaterialPageRoute(builder: (context) => SettingsScreen(vm));
                if (context.mounted) {
                  Navigator.push(context, route);
                }
              },
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.settings_outlined, size: 40, color: theme.colorScheme.primary),
                    SizedBox(height: 8),
                    Text('Settings', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
