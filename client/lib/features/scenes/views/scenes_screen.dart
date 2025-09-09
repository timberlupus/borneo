import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:provider/provider.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:event_bus/event_bus.dart';
import 'package:logger/logger.dart';

import '../view_models/scenes_view_model.dart';
import '../../../core/services/scene_manager.dart';
import '../../../core/services/devices/device_manager.dart';
import 'scene_edit_screen.dart';
import '../../chores/views/chore_list.dart';
import '../../chores/views/chore_list.dart' show ProvideChoresViewModel; // wrapper
import '../models/scene_edit_arguments.dart';
import 'scene_card.dart';

class ScenesScreen extends StatefulWidget {
  const ScenesScreen({super.key});
  @override
  State<ScenesScreen> createState() => _ScenesScreenState();
}

class _ScenesScreenState extends State<ScenesScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<ScenesViewModel>().initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScenesViewModel>();
    if (vm.isLoading && vm.scenes.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (vm.error != null && vm.scenes.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(context.translate('Error: {errMsg}', nArgs: {'errMsg': vm.error!})),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => context.read<ScenesViewModel>().initialize(),
              child: Text(context.translate('Retry')),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: () => context.read<ScenesViewModel>().initialize(),
      child: CustomScrollView(
        slivers: [
          SliverAppBar(
            title: Text(context.translate('Scenes')),
            actions: [
              IconButton(icon: const Icon(Icons.add_outlined), onPressed: () => _showNewSceneScreen(context)),
              if (vm.isLoading)
                const Padding(
                  padding: EdgeInsets.all(16.0),
                  child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                ),
            ],
          ),
          const _SceneList(),
          const ProvideChoresViewModel(child: ChoreList()),
          if (vm.error != null && vm.scenes.isNotEmpty)
            SliverToBoxAdapter(
              child: Container(
                margin: const EdgeInsets.all(16),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.errorContainer,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(Icons.error_outline, color: Theme.of(context).colorScheme.onErrorContainer),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(vm.error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                    ),
                    TextButton(
                      onPressed: () => context.read<ScenesViewModel>().initialize(),
                      child: Text(context.translate('Retry')),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _showNewSceneScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SceneEditScreen(args: SceneEditArguments(isCreation: true))),
    );
  }
}

class _SceneList extends StatefulWidget {
  const _SceneList();
  @override
  State<_SceneList> createState() => _SceneListState();
}

class _SceneListState extends State<_SceneList> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelected(int index) {
    if (!_scrollController.hasClients) return;
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight / 4.0;
    final cardWidth = cardHeight * (16.0 / 9.0);
    const separatorWidth = 16.0;
    final itemWidth = cardWidth + separatorWidth;
    final centerOffset = screenWidth / 2 - cardWidth / 2;
    final targetOffset = index * itemWidth - centerOffset;
    _scrollController.animateTo(
      targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScenesViewModel>();
    final scenes = vm.scenes;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedIndex = scenes.indexWhere((s) => s.isSelected);
      if (selectedIndex != -1) {
        _scrollToSelected(selectedIndex);
      }
    });
    final screenHeight = MediaQuery.of(context).size.height;
    return SliverToBoxAdapter(
      child: SizedBox(
        height: screenHeight / 4.0,
        child: ScrollConfiguration(
          behavior: const MaterialScrollBehavior().copyWith(
            dragDevices: {
              PointerDeviceKind.touch,
              PointerDeviceKind.mouse,
              PointerDeviceKind.stylus,
              PointerDeviceKind.unknown,
            },
          ),
          child: ListView.separated(
            controller: _scrollController,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            separatorBuilder: (_, _) => const SizedBox(width: 16),
            scrollDirection: Axis.horizontal,
            itemCount: scenes.length,
            itemBuilder: (_, index) {
              final scene = scenes[index];
              // Width now driven purely by card's internal AspectRatio (16:9) and list height
              return SceneCard(scene, onCentered: () => _scrollToSelected(index));
            },
          ),
        ),
      ),
    );
  }
}

/// Provide ScenesViewModel and dependencies at a high level
class ProvideScenesViewModel extends StatelessWidget {
  final Widget child;
  const ProvideScenesViewModel({required this.child, super.key});
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<ScenesViewModel>(
      create: (ctx) => ScenesViewModel(
        ctx.read<ISceneManager>(),
        ctx.read<IDeviceManager>(),
        ctx.read<EventBus>(),
        ctx.read<Logger?>(),
      ),
      child: child,
    );
  }
}
