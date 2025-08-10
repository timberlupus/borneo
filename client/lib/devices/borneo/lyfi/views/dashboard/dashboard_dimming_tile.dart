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
        final iconColor = isDisabled ? theme.colorScheme.primary.withValues(alpha: 0.38) : theme.colorScheme.primary;
        final textColor = isDisabled
            ? theme.colorScheme.onSurface.withValues(alpha: 0.38)
            : theme.colorScheme.onSurface;
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: (canUnlock && context.read<LyfiViewModel>().isOnline)
                    ? () async {
                        final vm = context.read<LyfiViewModel>();
                        // Request entering dimming (unlock) then wait for readiness event-driven
                        vm.toggleLock(false);
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
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final iconSize = constraints.maxHeight * 0.3;
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Icon(Icons.tips_and_updates_outlined, size: iconSize, color: iconColor),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            context.translate('Dimming'),
                            style: theme.textTheme.titleMedium?.copyWith(color: textColor),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
