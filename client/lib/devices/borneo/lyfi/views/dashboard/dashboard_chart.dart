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
    return Selector<LyfiViewModel, ({bool isOnline, LyfiMode mode, LyfiState? state, bool isOn})>(
      selector: (_, vm) => (isOnline: vm.isOnline, mode: vm.mode, state: vm.state, isOn: vm.isOn),
      builder: (context, props, _) {
        if (!props.isOnline) {
          return const SizedBox.shrink();
        }
        final Widget widget = switch (props.mode) {
          LyfiMode.manual => ManualRunningChart(),
          LyfiMode.scheduled => ScheduleRunningChart(),
          LyfiMode.sun => Selector<LyfiViewModel, ({List<LyfiChannelInfo> channels, List<ScheduledInstant> instants})>(
            selector: (context, vm) => (channels: vm.lyfiDeviceInfo.channels, instants: vm.sunInstants),
            builder: (context, selected, _) =>
                SunRunningChart(sunInstants: selected.instants, channelInfoList: selected.channels),
          ),
        };

        return AnimatedSwitcher(
          duration: Duration(milliseconds: 100), // 减少动画时间，让图表快速出现
          transitionBuilder: (Widget child, Animation<double> animation) {
            // 使用SlideTransition而不是FadeTransition，避免透明度变化影响背景
            return SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0.0, 0.1),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutQuart)),
              child: child,
            );
          },
          child: widget,
        );
      },
    );
  }
}
