import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';

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
        final textColor = isDisabled ? theme.colorScheme.primary.withValues(alpha: 0.38) : theme.colorScheme.primary;
        return AspectRatio(
          aspectRatio: 1,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: canUnlock ? () async => context.read<LyfiViewModel>().toggleLock(false) : null,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final iconSize = constraints.maxHeight * 0.3;
                  return Column(
                    children: [
                      Expanded(
                        child: Center(child: Icon(Icons.tips_and_updates_outlined, size: iconSize, color: iconColor)),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text('Dimming', style: theme.textTheme.titleMedium?.copyWith(color: textColor)),
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
