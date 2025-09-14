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
    final shouldShowLoading = state.isLoading && state.chores.isEmpty;
    final shouldShowSceneLoading = scenesVm?.isLoading == true;
    final showLoading = shouldShowLoading || shouldShowSceneLoading;

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.translate('Chores'), style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            AnimatedSize(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 400),
                switchInCurve: Curves.easeIn,
                switchOutCurve: Curves.easeOut,
                child: showLoading
                    ? SizedBox(
                        key: const ValueKey('scene_loading_text'),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 32),
                          child: Center(child: _FlowingLoadingText()),
                        ),
                      )
                    : _buildContent(context, state, selectedSceneId),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, ChoresViewModel vm, String? selectedSceneId) {
    final theme = Theme.of(context);
    if (vm.error != null && vm.chores.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              Text(context.translate('Error loading chores'), style: TextStyle(color: theme.colorScheme.error)),
              const SizedBox(height: 8),
              ElevatedButton(
                onPressed: () => context.read<ChoresViewModel>().initialize(),
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
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 500),
          child: GridView.builder(
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
              return TweenAnimationBuilder<double>(
                key: ValueKey('${selectedSceneId ?? 'none'}-${chore.runtimeType}-${chore.hashCode}'),
                tween: Tween(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + index * 40),
                curve: Curves.easeOutCubic,
                builder: (context, value, child) => Opacity(
                  opacity: value,
                  child: Transform.translate(offset: Offset(0, (1 - value) * 16), child: child),
                ),
                child: ChoreCard(chore),
              );
            },
          ),
        ),
        if (vm.isLoading && chores.isNotEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
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

class _FlowingLoadingText extends StatefulWidget {
  const _FlowingLoadingText({super.key});

  @override
  State<_FlowingLoadingText> createState() => _FlowingLoadingTextState();
}

class _FlowingLoadingTextState extends State<_FlowingLoadingText> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final baseColor = theme.colorScheme.onSurface.withValues(alpha: 0.45);
    final highlight = theme.colorScheme.onSurface.withValues(alpha: 0.9);

    return Semantics(
      label: context.translate('Loading chores'),
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, child) {
          return ShaderMask(
            shaderCallback: (bounds) {
              final width = bounds.width;
              final animationValue = _controller.value;
              final gradientWidth = width * 0.35;
              final dx = (width + gradientWidth) * animationValue - gradientWidth;

              return LinearGradient(
                colors: [baseColor, highlight, baseColor],
                stops: const [0.0, 0.5, 1.0],
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                transform: GradientTranslation(dx),
              ).createShader(bounds);
            },
            blendMode: BlendMode.srcIn,
            child: Text(
              context.translate('Loading...'),
              style: (theme.textTheme.titleSmall ?? theme.textTheme.bodyLarge)?.copyWith(fontWeight: FontWeight.w600),
            ),
          );
        },
      ),
    );
  }
}

class GradientTranslation extends GradientTransform {
  final double dx;
  const GradientTranslation(this.dx);

  @override
  Matrix4 transform(Rect bounds, {TextDirection? textDirection}) {
    return Matrix4.translationValues(dx, 0.0, 0.0);
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
