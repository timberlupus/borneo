import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../acclimation_screen.dart';

class DashboardAcclimationTile extends StatelessWidget {
  const DashboardAcclimationTile({super.key});

  @override
  Widget build(BuildContext context) {
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
}
