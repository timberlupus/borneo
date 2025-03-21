import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

import 'package:borneo_app/devices/borneo/lyfi/views/dashboard_view.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/schedule_editor_view.dart';
import 'package:borneo_app/services/device_manager.dart';

import '../view_models/lyfi_view_model.dart';
import 'manual_editor_view.dart';
import 'settings_screen.dart';

class CircleButton extends StatelessWidget {
  final String text;
  final Widget icon;
  final Color? color;
  final Color? backgroundColor;
  final VoidCallback? onPressed;

  const CircleButton({
    super.key,
    required this.text,
    required this.icon,
    this.color,
    this.backgroundColor,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(0),
      child: Column(
        children: [
          SizedBox(
            width: 48,
            height: 48,
            child: Container(
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10.0), color: backgroundColor),
              child: IconButton(
                onPressed: onPressed,
                padding: EdgeInsets.all(8),
                icon: icon,
                color: color,
                style: ButtonStyle(
                  shape: WidgetStateProperty.all<RoundedRectangleBorder>(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0),
                      side: BorderSide(color: Theme.of(context).colorScheme.outline, width: 1.0),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Divider(height: 2),
          Text(text, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    );
  }
}

class HeroVerticalDivider extends StatelessWidget {
  final double width;
  final Color color;

  const HeroVerticalDivider({super.key, this.width = 8, this.color = Colors.grey});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      color: Theme.of(context).colorScheme.surface,
      child: VerticalDivider(color: color, thickness: 1),
    );
  }
}

class HeroProgressIndicator extends StatelessWidget {
  final Widget? label;
  final Widget? center;
  final double radius;
  final double percent;
  final LinearGradient? linearGradient;
  final Widget? icon;

  const HeroProgressIndicator({
    super.key,
    this.radius = 24,
    this.percent = 0,
    this.center,
    this.label,
    this.linearGradient,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        CircularPercentIndicator(
          animateFromLastPercent: true,
          animation: true,
          radius: radius,
          arcType: ArcType.FULL,
          lineWidth: 1.5,
          percent: percent,
          center: center,
          footer: label,
          progressColor: Theme.of(context).colorScheme.primary,
          linearGradient: linearGradient,
          arcBackgroundColor: Theme.of(context).colorScheme.outlineVariant,
        ),
        if (icon != null) Positioned.fill(child: Align(alignment: Alignment.bottomCenter, child: icon!)),
      ],
    );
  }
}

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Consumer<LyfiViewModel>(
              builder: (context, vm, _) {
                return SegmentedButton<bool>(
                  showSelectedIcon: false,
                  selected: <bool>{vm.schedulerEnabled},
                  segments: [
                    ButtonSegment<bool>(value: true, label: Text('Sched.'), icon: Icon(Icons.line_axis_outlined)),
                    ButtonSegment<bool>(value: false, label: Text('Manual'), icon: Icon(Icons.bar_chart_outlined)),
                  ],
                  onSelectionChanged:
                      vm.isOn && !vm.isBusy && !vm.isLocked
                          ? (Set<bool> newSelection) {
                            if (vm.schedulerEnabled != newSelection.single) {
                              vm.switchSchedulerEnabled(newSelection.single);
                            }
                          }
                          : null,
                );
              },
            ),
            const Spacer(),
            Consumer<LyfiViewModel>(
              builder:
                  (context, vm, child) => HeroProgressIndicator(
                    percent: vm.currentTempRatio,
                    icon: Icon(Icons.thermostat_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                    center: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          vm.currentTemp != null ? '${vm.currentTemp}℃' : "N/A",
                          style: Theme.of(
                            context,
                          ).textTheme.bodyMedium?.copyWith(fontFeatures: [FontFeature.tabularFigures()]),
                        ),
                      ],
                    ),
                    /*
                label:
                    Text("Temp.", style: Theme.of(context).textTheme.bodySmall),
                    */
                  ),
            ),
            SizedBox(width: 16),
            Selector<LyfiViewModel, double?>(
              selector: (context, vm) => vm.fanPowerRatio,
              builder:
                  (context, fanPowerRatio, child) => HeroProgressIndicator(
                    percent: fanPowerRatio != null ? fanPowerRatio / 100.0 : 0,
                    icon: Icon(Icons.air_outlined, size: 16, color: Theme.of(context).colorScheme.outline),
                    center: Text(
                      fanPowerRatio != null ? "${fanPowerRatio.toStringAsFixed(0)}%" : "N/A",
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(fontFeatures: [FontFeature.tabularFigures()]),
                    ),
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class DimmingView extends StatelessWidget {
  const DimmingView({super.key});

  @override
  Widget build(BuildContext context) {
    //final String deviceID =
    //   ModalRoute.of(context)!.settings.arguments as String;
    return Column(
      spacing: 16,
      mainAxisAlignment: MainAxisAlignment.start,
      children: [
        HeroPanel(),
        Expanded(
          child: Selector<LyfiViewModel, ({bool isLocked, bool schedulerEnabled})>(
            selector: (context, vm) => (isLocked: vm.isLocked, schedulerEnabled: vm.schedulerEnabled),
            builder: (context, vm, child) {
              return AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: vm.schedulerEnabled ? ScheduleEditorView() : ManualEditorView(),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _LyfiDeviceDetailsScreen extends StatelessWidget {
  const _LyfiDeviceDetailsScreen();

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) {
          return;
        }
        final vm = context.read<LyfiViewModel>();
        if (!vm.isLocked) {
          vm.toggleLock(true);
        } else {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        backgroundColor: Theme.of(context).colorScheme.surface,
        appBar: AppBar(
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          backgroundColor: Theme.of(context).colorScheme.surface,
          title: Selector<LyfiViewModel, String>(
            selector: (_, vm) => vm.name,
            builder: (contet, name, _) => Text(name),
          ),
          leading: Selector<LyfiViewModel, bool>(
            selector: (context, vm) => vm.isBusy,
            builder:
                (context, isBusy, child) => IconButton(
                  icon: Icon(Icons.arrow_back),
                  onPressed:
                      isBusy
                          ? null
                          : () {
                            final vm = context.read<LyfiViewModel>();
                            if (vm.isLocked) {
                              Navigator.of(context).pop();
                            } else {
                              vm.toggleLock(true);
                            }
                          },
                ),
          ),
          actions: [
            Container(
              padding: EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              child: SizedBox(
                height: 16,
                width: 16,
                child: Selector<LyfiViewModel, ({bool isBusy, bool isOnline})>(
                  selector: (_, vm) => (isBusy: vm.isBusy, isOnline: vm.isOnline),
                  builder:
                      (context, vm, _) => Container(
                        child:
                            vm.isBusy
                                ? CircularProgressIndicator()
                                : !vm.isOnline
                                ? Icon(Icons.wifi_off_outlined, color: Theme.of(context).colorScheme.error)
                                : null,
                      ),
                ),
              ),
            ),
            /*
            Selector<LyfiViewModel, ({bool isOn, bool isLocked, bool isBusy})>(
              selector: (_, vm) =>
                  (isOn: vm.isOn, isLocked: vm.isLocked, isBusy: vm.isBusy),
              builder: (context, vm, _) => vm.isLocked
                  ? SizedBox()
                  : Padding(
                      padding: EdgeInsets.all(4),
                      child: IconButton(
                        icon: Icon(Icons.check, size: 24),
                        onPressed: vm.isOn && !vm.isBusy
                            ? () =>
                                context.read<LyfiViewModel>().toggleLock(true)
                            : null,
                      ),
                    ),
            ),
            */
            IconButton(
              icon: Icon(Icons.settings_outlined, size: 24),
              onPressed: () async {
                final vm = context.read<LyfiViewModel>();
                await Future.delayed(Duration(milliseconds: 200));
                final route = MaterialPageRoute(builder: (context) => SettingsScreen(vm));
                if (context.mounted) {
                  Navigator.push(context, route);
                }
              },
            ),
          ],
        ),
        body: Selector<LyfiViewModel, ({bool isLocked})>(
          selector: (_, vm) => (isLocked: vm.isLocked),
          builder:
              (context, vm, _) => AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: vm.isLocked ? DashboardView() : DimmingView(),
              ),
        ),
      ),
    );
  }
}

class LyfiScreen extends StatelessWidget {
  const LyfiScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = ModalRoute.of(context)!.settings.arguments as DeviceEntity;
    return ChangeNotifierProvider(
      create: (cb) => LyfiViewModel(device.id, cb.read<DeviceManager>(), globalEventBus: cb.read<EventBus>()),
      builder: (context, child) {
        final vm = context.read<LyfiViewModel>();
        return FutureBuilder(
          future: vm.isInitialized ? null : vm.initialize(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            } else if (snapshot.hasError) {
              return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
            } else {
              return _LyfiDeviceDetailsScreen();
            }
          },
        );
      },
    );
  }
}
