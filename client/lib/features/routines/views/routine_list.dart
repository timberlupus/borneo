import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';

import '../view_models/routines_view_model.dart';
import 'routine_card.dart';
import '../models/abstract_routine.dart';
import '../../../core/services/routine_manager.dart';
import '../../../core/services/scene_manager.dart';
import '../../../core/services/app_notification_service.dart';
import 'package:logger/logger.dart';
import 'package:event_bus/event_bus.dart';

class RoutineList extends StatefulWidget {
  const RoutineList({super.key});
  @override
  State<RoutineList> createState() => _RoutineListState();
}

class _RoutineListState extends State<RoutineList> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RoutinesViewModel>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = context.watch<RoutinesViewModel>();
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.translate('Routines'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            _buildContent(context, state),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, RoutinesViewModel vm) {
    final theme = Theme.of(context);
    if (vm.isLoading && vm.routines.isEmpty) {
      return const Center(
        child: Padding(padding: EdgeInsets.symmetric(vertical: 32), child: CircularProgressIndicator()),
      );
    }
    if (vm.error != null && vm.routines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Text(context.translate('Error loading routines'), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.read<RoutinesViewModel>().initialize(),
                child: Text(context.translate('Retry')),
              ),
            ],
          ),
        ),
      );
    }
    final List<AbstractRoutine> routines = vm.routines;
    if (routines.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.block, size: 56, color: theme.colorScheme.onSurface.withValues(alpha: 0.5)),
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
            padding: EdgeInsets.zero,
            itemCount: routines.length,
            itemBuilder: (_, index) => RoutineCard(routines[index]),
          ),
        ),
        if (vm.isLoading && routines.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
          ),
        if (vm.error != null && routines.isNotEmpty)
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
                  onPressed: () => context.read<RoutinesViewModel>().initialize(),
                  child: Text(context.translate('Retry')),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// Helper wrapper to provide RoutinesViewModel in a scope where underlying services exist.
class ProvideRoutinesViewModel extends StatelessWidget {
  final Widget child;
  const ProvideRoutinesViewModel({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<RoutinesViewModel>(
      create: (ctx) => RoutinesViewModel(
        ctx.read<IRoutineManager>(),
        ctx.read<ISceneManager>(),
        ctx.read<IAppNotificationService>(),
        ctx.read<EventBus>(),
        ctx.read<Logger?>(),
      ),
      child: child,
    );
  }
}
