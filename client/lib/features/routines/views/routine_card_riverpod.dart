import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:borneo_app/features/routines/models/abstract_routine.dart';
import 'package:borneo_app/features/routines/providers/routine_summary_provider.dart';

class RoutineCardRiverpod extends ConsumerWidget {
  final AbstractRoutine routine;
  const RoutineCardRiverpod(this.routine, {super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final routineSummaryState = ref.watch(routineSummaryProvider(routine));
    final routineSummaryNotifier = ref.read(routineSummaryProvider(routine).notifier);

    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: routineSummaryState.isBusy ? null : () => _onTap(routineSummaryNotifier, routineSummaryState.isActive),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon container
              Container(
                width: 48,
                height: 48,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: routineSummaryState.isActive ? colorScheme.primary : colorScheme.surface,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: routineSummaryState.isActive ? colorScheme.primary : colorScheme.outline,
                    width: 1,
                  ),
                ),
                child: _buildIcon(context, routineSummaryState),
              ),
              const SizedBox(height: 12),
              // Routine name
              Text(
                routineSummaryState.name,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              // Status indicator
              _buildStatusIndicator(context, routineSummaryState),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIcon(BuildContext context, RoutineSummaryState state) {
    final colorScheme = Theme.of(context).colorScheme;

    if (state.isBusy) {
      return SizedBox(
        width: 24,
        height: 24,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          color: state.isActive ? colorScheme.onPrimary : colorScheme.primary,
        ),
      );
    }

    final iconColor = state.isActive ? colorScheme.onPrimary : colorScheme.onSurface;

    if (state.iconAssetPath.endsWith('.svg')) {
      return SvgPicture.asset(
        state.iconAssetPath,
        width: 24,
        height: 24,
        colorFilter: ColorFilter.mode(iconColor, BlendMode.srcIn),
      );
    } else {
      return Image.asset(state.iconAssetPath, width: 24, height: 24, color: iconColor);
    }
  }

  Widget _buildStatusIndicator(BuildContext context, RoutineSummaryState state) {
    final colorScheme = Theme.of(context).colorScheme;

    if (state.error != null) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
        child: Text(context.translate('Error'), style: TextStyle(fontSize: 12, color: colorScheme.onErrorContainer)),
      );
    }

    if (state.isActive) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(color: colorScheme.primaryContainer, borderRadius: BorderRadius.circular(12)),
        child: Text(context.translate('Active'), style: TextStyle(fontSize: 12, color: colorScheme.onPrimaryContainer)),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest, borderRadius: BorderRadius.circular(12)),
      child: Text(
        context.translate('Tap to activate'),
        style: TextStyle(fontSize: 12, color: colorScheme.onSurface.withOpacity(0.7)),
      ),
    );
  }

  void _onTap(RoutineSummaryNotifier notifier, bool isActive) {
    if (isActive) {
      notifier.undoRoutine();
    } else {
      notifier.executeRoutine();
    }
  }
}
