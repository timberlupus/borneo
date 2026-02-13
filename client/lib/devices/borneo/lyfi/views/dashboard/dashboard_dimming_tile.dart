import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../dimming_screen.dart';

class DashboardDimmingTile extends StatelessWidget {
  const DashboardDimmingTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, bool>(
      selector: (_, vm) => vm.canUnlock,
      builder: (context, canUnlock, _) {
        final theme = Theme.of(context);
        final isDisabled = !canUnlock;
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
                onTap: (canUnlock && context.read<LyfiViewModel>().isOnline)
                    ? () async {
                        final vm = context.read<LyfiViewModel>();
                        // Request entering dimming (unlock) then wait for readiness event-driven
                        await vm.toggleLock(false);
                        await vm.onDimmingReady();

                        if (context.mounted) {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => ChangeNotifierProvider.value(value: vm, child: const DimmingScreen()),
                            ),
                          );
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.tips_and_updates_outlined, size: 32, color: effectiveIconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.translate('Dimming'),
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
