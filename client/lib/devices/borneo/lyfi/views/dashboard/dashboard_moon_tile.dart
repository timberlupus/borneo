import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../moon_screen.dart';

class DashboardMoonTile extends StatelessWidget {
  const DashboardMoonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({bool isOnline, bool isOn})>(
      selector: (_, vm) => (isOnline: vm.isOnline, isOn: vm.isOn),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isDisabled = !props.isOnline || !props.isOn;
        final Color bgColor = theme.colorScheme.surfaceContainerHighest;
        final Color fgColor = theme.colorScheme.onSurface;
        final double disabledAlpha = 0.38;
        final Color effectiveFgColor = isDisabled ? fgColor.withValues(alpha: disabledAlpha) : fgColor;
        final Color iconColor = theme.colorScheme.primary;
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
                          final route = MaterialPageRoute(builder: (context) => MoonScreen(deviceID: vm.deviceID));
                          await Navigator.push(context, route);
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.nightlight_outlined, size: 32, color: effectiveIconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.translate('Moonlight'),
                              style: theme.textTheme.titleMedium?.copyWith(color: effectiveFgColor),
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
}
