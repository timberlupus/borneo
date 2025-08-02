import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:borneo_app/features/scenes/providers/scenes_provider.dart';
import 'package:borneo_app/features/scenes/providers/scene_edit_provider.dart';
import 'package:borneo_app/features/routines/views/routine_list_riverpod.dart';
import 'scene_card_riverpod.dart';
import 'scene_edit_screen.dart';

class SceneListRiverpod extends ConsumerStatefulWidget {
  const SceneListRiverpod({super.key});

  @override
  ConsumerState<SceneListRiverpod> createState() => _SceneListRiverpodState();
}

class _SceneListRiverpodState extends ConsumerState<SceneListRiverpod> {
  final ScrollController _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _scrollToSelectedCard(int index) {
    if (!_scrollController.hasClients) return;

    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final cardHeight = screenHeight / 4.0;
    final cardWidth = cardHeight * (16.0 / 9.0); // Based on aspect ratio 16:9
    final separatorWidth = 16.0;
    final itemWidth = cardWidth + separatorWidth;

    // Calculate center offset
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
    final scenesState = ref.watch(scenesProvider);
    double screenHeight = MediaQuery.of(context).size.height;

    // Scroll to selected card when it changes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final selectedIndex = scenesState.scenes.indexWhere((scene) => scene.isSelected);
      if (selectedIndex != -1) {
        _scrollToSelectedCard(selectedIndex);
      }
    });

    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.all(0),
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
            itemCount: scenesState.scenes.length,
            itemBuilder: (context, index) {
              return SceneCardRiverpod(scenesState.scenes[index], onTap: () => _scrollToSelectedCard(index));
            },
          ),
        ),
      ),
    );
  }
}

class ScenesScreenRiverpod extends ConsumerStatefulWidget {
  const ScenesScreenRiverpod({super.key});

  @override
  ConsumerState<ScenesScreenRiverpod> createState() => _ScenesScreenRiverpodState();
}

class _ScenesScreenRiverpodState extends ConsumerState<ScenesScreenRiverpod> {
  @override
  void initState() {
    super.initState();
    // Initialize the scenes when the widget is first created
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(scenesProvider.notifier).initialize();
    });
  }

  @override
  Widget build(BuildContext context) {
    final scenesState = ref.watch(scenesProvider);

    if (scenesState.isLoading && scenesState.scenes.isEmpty) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (scenesState.error != null && scenesState.scenes.isEmpty) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                context.translate('Error: {errMsg}', nArgs: {'errMsg': scenesState.error!}),
                style: Theme.of(context).textTheme.bodyLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.read(scenesProvider.notifier).initialize(),
                child: Text(context.translate('Retry')),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => ref.read(scenesProvider.notifier).initialize(),
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                title: Text(context.translate('Scenes')),
                actions: [
                  IconButton(icon: const Icon(Icons.add_outlined), onPressed: () => _showNewSceneScreen(context)),
                  if (scenesState.isLoading)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                    ),
                ],
              ),
              const SceneListRiverpod(),
              const RoutineListRiverpod(), // Use Riverpod version of RoutineList
              // Error display at the bottom if there's an error but we have scenes
              if (scenesState.error != null && scenesState.scenes.isNotEmpty)
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
                          child: Text(
                            scenesState.error!,
                            style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer),
                          ),
                        ),
                        TextButton(
                          onPressed: () => ref.read(scenesProvider.notifier).initialize(),
                          child: Text(context.translate('Retry')),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showNewSceneScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SceneEditScreen(args: SceneEditArguments(isCreation: true))),
    );
  }
}
