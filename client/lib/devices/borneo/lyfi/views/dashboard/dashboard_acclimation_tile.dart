import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../acclimation_screen.dart';

class DashboardAcclimationTile extends StatelessWidget {
  const DashboardAcclimationTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({bool isOnline, bool isOn, bool enabled, bool activated})>(
      selector: (_, vm) => (
        isOnline: vm.isOnline,
        isOn: vm.isOn,
        enabled: vm.lyfiThing.getProperty<bool>('acclimationEnabled')!,
        activated: vm.lyfiThing.getProperty<bool>('acclimationActivated')!,
      ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isActive = props.enabled || props.activated;
        final isDisabled = !props.isOnline || !props.isOn;
        final Color bgColor = isActive ? theme.colorScheme.primaryContainer : theme.colorScheme.surfaceContainerHighest;
        final Color fgColor = isActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;
        final double disabledAlpha = 0.38;
        final Color effectiveFgColor = isDisabled ? fgColor.withValues(alpha: disabledAlpha) : fgColor;
        final Color iconColor = isActive ? theme.colorScheme.onPrimary : theme.colorScheme.primary;
        final Color effectiveIconColor = isDisabled ? iconColor.withValues(alpha: disabledAlpha) : iconColor;
        return AspectRatio(
          aspectRatio: 2.0,
          child: Container(
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: props.isOnline && props.isOn
                    ? () async {
                        if (context.mounted) {
                          final vm = context.read<LyfiViewModel>();
                          final route = MaterialPageRoute(
                            builder: (context) => AcclimationScreen(deviceID: vm.deviceID),
                          );
                          await Navigator.push(context, route);
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Stack(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(Icons.calendar_month_outlined, size: 32, color: effectiveIconColor),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.translate("Acclimation"),
                                  style: theme.textTheme.titleMedium?.copyWith(color: effectiveFgColor),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (isActive)
                        Positioned(
                          right: -16,
                          bottom: -16,
                          child: Icon(
                            Icons.calendar_month_outlined,
                            size: 64,
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.15),
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
}
