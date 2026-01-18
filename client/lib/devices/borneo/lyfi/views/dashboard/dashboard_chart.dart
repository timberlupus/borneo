import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../widgets/manual_running_chart.dart';
import '../widgets/schedule_running_chart.dart';
import '../widgets/sun_running_chart.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

class DashboardChart extends StatelessWidget {
  const DashboardChart({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({bool isOnline, LyfiMode mode, LyfiState? state, bool isOn, bool cloudActivated})>(
      selector: (_, vm) => (
        isOnline: vm.isOnline,
        mode: vm.mode,
        state: vm.state,
        isOn: vm.isOn,
        cloudActivated: vm.lyfiDeviceStatus?.cloudActivated ?? false,
      ),
      builder: (context, props, _) {
        if (!props.isOnline) {
          return const SizedBox.shrink();
        }
        final modeIcon = switch (props.mode) {
          LyfiMode.manual => Icons.bar_chart_outlined,
          LyfiMode.scheduled => Icons.alarm_outlined,
          LyfiMode.sun => Icons.wb_sunny_outlined,
        };

        final chartWidget = switch (props.mode) {
          LyfiMode.manual => ManualRunningChart(),
          LyfiMode.scheduled => ScheduleRunningChart(),
          LyfiMode.sun => Selector<LyfiViewModel, ({List<LyfiChannelInfo> channels, ScheduleTable instants})>(
            selector: (context, vm) => (channels: vm.lyfiDeviceInfo.channels, instants: vm.sunInstants),
            builder: (context, selected, _) =>
                SunRunningChart(sunInstants: selected.instants, channelInfoList: selected.channels),
          ),
        };

        return AnimatedSwitcher(
          duration: Duration(milliseconds: 300),
          transitionBuilder: (Widget child, Animation<double> animation) {
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
              child: child,
            );
          },
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 200),
            child: LayoutBuilder(
              builder: (context, constraints) {
                final iconSize =
                    ((constraints.maxWidth < constraints.maxHeight ? constraints.maxWidth : constraints.maxHeight) *
                            0.50)
                        .clamp(0, double.infinity)
                        .toDouble();
                return Stack(
                  children: [
                    Positioned(
                      right: -iconSize * 0.1,
                      bottom: -iconSize * 0.1,
                      child: IgnorePointer(
                        child: Icon(
                          modeIcon,
                          size: iconSize,
                          color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .03),
                        ),
                      ),
                    ),
                    Positioned.fill(child: chartWidget),
                    Positioned(
                      right: 12,
                      top: 12,
                      child: AnimatedOpacity(
                        opacity: props.cloudActivated ? 1.0 : 0.0,
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeInOut,
                        child: Icon(
                          Icons.cloud,
                          size: 24,
                          color: Theme.of(context).colorScheme.secondary,
                          shadows: const [Shadow(color: Colors.black26, blurRadius: 2, offset: Offset(1, 1))],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        );
      },
    );
  }
}
