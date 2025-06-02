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
    return Selector<LyfiViewModel, ({bool isOnline, LedRunningMode mode, LedState? state, bool isOn})>(
      selector: (_, vm) => (isOnline: vm.isOnline, mode: vm.mode, state: vm.ledState, isOn: vm.isOn),
      builder: (context, props, _) {
        if (!props.isOnline) {
          return const SizedBox.shrink();
        }
        final Widget widget = switch (props.mode) {
          LedRunningMode.manual => ManualRunningChart(),
          LedRunningMode.scheduled => ScheduleRunningChart(),
          LedRunningMode.sun =>
            Selector<LyfiViewModel, ({List<LyfiChannelInfo> channels, List<ScheduledInstant> instants})>(
              selector: (context, vm) => (channels: vm.lyfiDeviceInfo.channels, instants: vm.sunInstants),
              builder:
                  (context, selected, _) =>
                      SunRunningChart(sunInstants: selected.instants, channelInfoList: selected.channels),
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
    );
  }
}
