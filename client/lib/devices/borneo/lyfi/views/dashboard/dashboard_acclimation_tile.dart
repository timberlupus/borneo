import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../acclimation_screen.dart';

class DashboardAcclimationTile extends StatelessWidget {
  const DashboardAcclimationTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({bool isOnline, bool isOn, bool enabled, bool activated})>(
      selector:
          (_, vm) => (
            isOnline: vm.isOnline,
            isOn: vm.isOn,
            enabled: vm.isOnline ? vm.lyfiDeviceStatus?.acclimationEnabled ?? false : false,
            activated: vm.isOnline ? vm.lyfiDeviceStatus?.acclimationActivated ?? false : false,
          ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isActive = props.enabled || props.activated;
        final isDisabled = !props.isOnline || !props.isOn;
        final iconColor =
            isDisabled
                ? (isActive
                    ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.38)
                    : theme.colorScheme.primary.withValues(alpha: 0.38))
                : (isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary);
        final textColor =
            isDisabled
                ? (isActive
                    ? theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.38)
                    : theme.colorScheme.primary.withValues(alpha: 0.38))
                : (isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.primary);
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
                  props.isOnline && props.isOn
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
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final iconSize = constraints.maxHeight * 0.3;
                  return Column(
                    children: [
                      Expanded(
                        child: Center(child: Icon(Icons.calendar_month_outlined, size: iconSize, color: iconColor)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('Acclimation', style: theme.textTheme.titleMedium?.copyWith(color: textColor)),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}
