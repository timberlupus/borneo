import 'package:borneo_app/devices/borneo/lyfi/views/sun_editor_view.dart';
import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

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

/*
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
*/

class HeroPanel extends StatelessWidget {
  const HeroPanel({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).colorScheme.surface,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Consumer<LyfiViewModel>(
              builder: (context, vm, _) {
                return SegmentedButton<LedRunningMode>(
                  showSelectedIcon: false,
                  selected: <LedRunningMode>{vm.mode},
                  segments: [
                    ButtonSegment<LedRunningMode>(
                      value: LedRunningMode.manual,
                      label: Text('MANU'),
                      icon: Icon(Icons.bar_chart_outlined, size: 24),
                    ),
                    ButtonSegment<LedRunningMode>(
                      value: LedRunningMode.scheduled,
                      label: Text('SCHED'),
                      icon: Icon(Icons.alarm_outlined, size: 24),
                    ),
                    ButtonSegment<LedRunningMode>(
                      value: LedRunningMode.sun,
                      label: Text('SUN'),
                      icon: Icon(Icons.wb_sunny_outlined, size: 24),
                    ),
                  ],
                  onSelectionChanged:
                      vm.isOn && !vm.isBusy && !vm.isLocked
                          ? (Set<LedRunningMode> newSelection) {
                            if (vm.mode != newSelection.single) {
                              vm.switchMode(newSelection.single);
                            }
                          }
                          : null,
                );
              },
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
          child: Selector<LyfiViewModel, ({bool isLocked, LedRunningMode mode})>(
            selector: (context, vm) => (isLocked: vm.isLocked, mode: vm.mode),
            builder: (context, vm, child) {
              return AnimatedSwitcher(
                duration: Duration(milliseconds: 300),
                transitionBuilder: (Widget child, Animation<double> animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: switch (vm.mode) {
                  LedRunningMode.manual => ManualEditorView(),
                  LedRunningMode.scheduled => ScheduleEditorView(),
                  LedRunningMode.sun => SunEditorView(),
                },
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
                (context, isBusy, child) =>
                    IconButton(icon: Icon(Icons.arrow_back), onPressed: isBusy ? null : () => goBack(context)),
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
            Selector<LyfiViewModel, RssiLevel?>(
              selector: (_, vm) => vm.rssiLevel,
              builder:
                  (content, rssi, _) => switch (rssi) {
                    null => Icon(Icons.signal_wifi_off_outlined, size: 24),
                    RssiLevel.strong => Icon(Icons.wifi, size: 24),
                    RssiLevel.medium => Icon(Icons.wifi_2_bar, size: 24),
                    RssiLevel.weak => Icon(Icons.wifi_1_bar, size: 24),
                  },
            ),
            SizedBox(width: 16),
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

  void goBack(BuildContext context) async {
    final vm = context.read<LyfiViewModel>();
    if (vm.isLocked) {
      Navigator.of(context).pop();
    } else {
      vm.toggleLock(true);
    }
  }
}

class LyfiView extends StatelessWidget {
  const LyfiView({super.key});

  @override
  Widget build(BuildContext context) {
    final device = ModalRoute.of(context)!.settings.arguments as DeviceEntity;
    return ChangeNotifierProvider(
      create:
          (cb) => LyfiViewModel(
            deviceID: device.id,
            deviceManager: cb.read<DeviceManager>(),
            globalEventBus: cb.read<EventBus>(),
          ),
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
