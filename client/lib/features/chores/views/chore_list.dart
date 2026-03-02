import 'package:flutter/material.dart';

import 'package:provider/provider.dart' as legacy;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import '../providers/chores_provider.dart';
import '../providers/chore_summary_provider.dart';
import '../../scenes/providers/scenes_provider.dart';
import 'chore_card.dart';
import '../models/abstract_chore.dart';
import '../../../core/providers.dart';
import '../../../core/services/chore_manager.dart';
import '../../../core/services/app_notification_service.dart';

class ChoreList extends ConsumerStatefulWidget {
  const ChoreList({super.key});
  @override
  ConsumerState<ChoreList> createState() => _ChoreListState();
}

class _ChoreListState extends ConsumerState<ChoreList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(choresProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(choresProvider);
    final scenesLoading = ref.watch(scenesIsLoadingProvider);

    Widget content = SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.translate('Chores'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildContent(context, state),
          ],
        ),
      ),
    );

    if (scenesLoading) {
      content = SliverIgnorePointer(key: const Key('chore_absorber'), ignoring: true, sliver: content);
    }

    return content;
  }

  Widget _buildContent(BuildContext context, ChoresState state) {
    final theme = Theme.of(context);
    if (state.isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (state.error != null && state.chores.isEmpty && !state.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Text(context.translate('Error loading chores'), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => ref.read(choresProvider.notifier).refresh(),
                child: Text(context.translate('Retry')),
              ),
            ],
          ),
        ),
      );
    }

    final List<AbstractChore> chores = state.chores;
    if (chores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
              const SizedBox(height: 16),
              Text(
                context.translate('No chores'),
                style: theme.textTheme.titleMedium?.copyWith(
                  color: theme.colorScheme.onSurface,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                context.translate('No chores available for devices in the current scene.'),
                textAlign: TextAlign.center,
                style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        GridView.builder(
          key: ValueKey(chores.length),
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 16.0,
            mainAxisSpacing: 16.0,
          ),
          padding: EdgeInsets.zero,
          itemCount: chores.length,
          itemBuilder: (_, index) {
            final chore = chores[index];
            return ChoreCard(chore);
          },
        ),
        if (state.error != null && chores.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(state.error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
                TextButton(
                  onPressed: () => ref.read(choresProvider.notifier).initialize(),
                  child: Text(context.translate('Retry')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Bridges the legacy [IChoreManager] and [IAppNotificationService] from the
/// old `provider` tree into Riverpod, then scopes [choresProvider] and
/// [choreSummaryProvider] so [ChoreList] and [ChoreCard] can consume them.
class ProvideChoresViewModel extends StatelessWidget {
  final Widget child;
  const ProvideChoresViewModel({required this.child, super.key});

  @override
  Widget build(BuildContext context) {
    final choreManager = legacy.Provider.of<IChoreManager>(context, listen: false);
    final notification = legacy.Provider.of<IAppNotificationService>(context, listen: false);
    return ProviderScope(
      overrides: [
        choreManagerProvider.overrideWithValue(choreManager),
        appNotificationServiceProvider.overrideWithValue(notification),
        choresProvider.overrideWith(ChoresNotifier.new),
        choreSummaryProvider.overrideWith2((arg) => ChoreSummaryNotifier(arg)),
      ],
      child: child,
    );
  }
}
