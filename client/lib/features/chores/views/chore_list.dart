import 'package:flutter/material.dart';

import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import '../view_models/chores_view_model.dart';
import '../../scenes/view_models/scenes_view_model.dart';
import 'chore_card.dart';
import '../models/abstract_chore.dart';
import '../../../core/services/chore_manager.dart';
import '../../../core/services/scene_manager.dart';
import '../../../core/services/app_notification_service.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';

class ChoreList extends StatefulWidget {
  const ChoreList({super.key});
  @override
  State<ChoreList> createState() => _ChoreListState();
}

class _ChoreListState extends State<ChoreList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ChoresViewModel>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<ChoresViewModel>();
    // Also watch scenes to trigger animation when scene changes
    final scenesVm = context.watch<ScenesViewModel?>();
    String? selectedSceneId;
    if (scenesVm != null) {
      try {
        selectedSceneId = scenesVm.scenes.firstWhere((s) => s.isSelected).id;
      } catch (_) {}
    }
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.translate('Chores'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            // Always render the chores content; remove the loading animation.
            _buildContent(context, state, selectedSceneId),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChoresViewModel vm, String? selectedSceneId) {
    final theme = Theme.of(context);
    if (vm.error != null && vm.chores.isEmpty && !vm.isLoading) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Text(context.translate('Error loading chores'), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.read<ChoresViewModel>().refresh(),
                child: Text(context.translate('Retry')),
              ),
            ],
          ),
        ),
      );
    }
    final List<AbstractChore> chores = vm.chores;
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
        if (vm.error != null && chores.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(top: 16),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: theme.colorScheme.errorContainer, borderRadius: BorderRadius.circular(8)),
            child: Row(
              children: [
                Icon(Icons.error_outline, color: theme.colorScheme.onErrorContainer),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(vm.error!, style: TextStyle(color: theme.colorScheme.onErrorContainer)),
                ),
                TextButton(
                  onPressed: () => context.read<ChoresViewModel>().initialize(),
                  child: Text(context.translate('Retry')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Helper wrapper to provide ChoresViewModel in a scope where underlying services exist.
class ProvideChoresViewModel extends StatelessWidget {
  final Widget child;
  const ProvideChoresViewModel({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ChoresViewModel>(
      create: (ctx) => ChoresViewModel(
        ctx.read<IChoreManager>(),
        ctx.read<ISceneManager>(),
        ctx.read<IAppNotificationService>(),
        ctx.read<EventBus>(),
        ctx.read<Logger?>(),
      ),
      child: child,
    );
  }
}
