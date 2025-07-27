import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:borneo_app/features/routines/providers/routines_provider.dart';
import 'package:borneo_app/features/routines/views/routine_card_riverpod.dart';

class RoutineListRiverpod extends ConsumerStatefulWidget {
  const RoutineListRiverpod({super.key});

  @override
  ConsumerState<RoutineListRiverpod> createState() => _RoutineListRiverpodState();
}

class _RoutineListRiverpodState extends ConsumerState<RoutineListRiverpod> {
  @override
  void initState() {
    super.initState();
    // Initialize the routines when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(routinesProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final routinesState = ref.watch(routinesProvider);

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.translate('Routines'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildRoutinesContent(context, routinesState),
          ],
        ),
      ),
    );
  }

  Widget _buildRoutinesContent(BuildContext context, RoutinesState routinesState) {
    final theme = Theme.of(context);
    if (routinesState.isLoading && routinesState.routines.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.symmetric(vertical: 32), child: CircularProgressIndicator()),
      );
    }

    if (routinesState.error != null && routinesState.routines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Text(context.translate('Error loading routines'), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.read(routinesProvider.notifier).initialize(),
                child: Text(context.translate('Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final routines = routinesState.routines;
    if (routines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.block, // Represents 'none' or 'not available'
                size: 56,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                context.translate('No routines'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.translate('No routines available for devices in the current scene.'),
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: GridView.builder(
            key: ValueKey(routines.length),
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 16.0,
              mainAxisSpacing: 16.0,
            ),
            padding: const EdgeInsets.all(0.0),
            itemCount: routines.length,
            itemBuilder: (context, index) {
              return RoutineCardRiverpod(routines[index]);
            },
          ),
        ),
        // Show loading indicator at the bottom if refreshing while having data
        if (routinesState.isLoading && routines.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        // Show error at the bottom if there's an error but we have data
        if (routinesState.error != null && routines.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(routinesState.error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
                TextButton(
                  onPressed: () => ref.read(routinesProvider.notifier).initialize(),
                  child: Text(context.translate('Retry')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
