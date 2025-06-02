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
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.tips_and_updates_outlined, size: 40, color: theme.colorScheme.primary),
                    SizedBox(height: 8),
                    Text('Dimming', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
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
