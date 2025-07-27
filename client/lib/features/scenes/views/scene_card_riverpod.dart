import 'dart:io';

import 'package:borneo_app/features/scenes/providers/scene_edit_provider.dart';
import 'package:borneo_app/features/scenes/providers/scenes_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'scene_edit_screen.dart';

class SceneCardRiverpod extends ConsumerWidget {
  final SceneSummaryState scene;
  final VoidCallback? onTap;
  static const _smallShadow = Shadow(offset: Offset(1.0, 1.0), blurRadius: 2.0, color: Color.fromARGB(128, 0, 0, 0));

  const SceneCardRiverpod(this.scene, {super.key, this.onTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8),
      clipBehavior: Clip.antiAlias,
      borderOnForeground: true,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
      child: AspectRatio(
        aspectRatio: 16.0 / 9.0,
        child: Material(
          color: scene.isSelected
              ? Theme.of(context).colorScheme.primaryContainer
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16.0),
          child: InkWell(
            onTap: () async {
              if (onTap != null) onTap!();
              if (!scene.isSelected) {
                await ref.read(scenesProvider.notifier).switchCurrentScene(scene.id);
              }
            },
            child: scene.isSelected
                ? Stack(
                    alignment: Alignment.topRight,
                    children: [
                      _buildSceneImage(context),
                      _buildSceneInfo(context),
                      if (scene.isSelected)
                        Positioned.fill(
                          child: ShaderMask(
                            shaderCallback: (Rect bounds) {
                              return RadialGradient(
                                center: Alignment.center,
                                radius: 0.5,
                                colors: [Colors.white.withAlpha(200), Colors.white],
                                stops: const [0.0, 1.0],
                                tileMode: TileMode.clamp,
                              ).createShader(bounds);
                            },
                            blendMode: BlendMode.srcATop,
                            child: Container(color: Colors.transparent),
                          ),
                        ),
                      Positioned(
                        top: 8.0,
                        right: 8.0,
                        child: IconButton(
                          onPressed: () {
                            _showEditSceneScreen(context);
                          },
                          icon: const Icon(Icons.edit_outlined, color: Colors.white, shadows: [_smallShadow]),
                        ),
                      ),
                    ],
                  )
                : TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: scene.isSelected ? 0.0 : 1.0, end: scene.isSelected ? 0.0 : 1.0),
                    duration: const Duration(milliseconds: 300),
                    builder: (context, value, child) {
                      final double s = 1.0 - 0.1 * value;
                      final double b = 1.0 - 0.1 * value;
                      final matrix = <double>[
                        s * b,
                        (1 - s) * b,
                        (1 - s) * b,
                        0,
                        0,
                        (1 - s) * b,
                        s * b,
                        (1 - s) * b,
                        0,
                        0,
                        (1 - s) * b,
                        (1 - s) * b,
                        s * b,
                        0,
                        0,
                        0,
                        0,
                        0,
                        1,
                        0,
                      ];
                      return ColorFiltered(
                        colorFilter: ColorFilter.matrix(matrix),
                        child: Stack(
                          alignment: Alignment.topRight,
                          children: [
                            _buildSceneImage(context),
                            _buildSceneInfo(context),
                            if (scene.isSelected)
                              Positioned.fill(
                                child: ShaderMask(
                                  shaderCallback: (Rect bounds) {
                                    return RadialGradient(
                                      center: Alignment.center,
                                      radius: 0.5,
                                      colors: [Colors.white.withAlpha(200), Colors.white],
                                      stops: const [0.0, 1.0],
                                      tileMode: TileMode.clamp,
                                    ).createShader(bounds);
                                  },
                                  blendMode: BlendMode.srcATop,
                                  child: Container(color: Colors.transparent),
                                ),
                              ),
                            Positioned(
                              top: 8.0,
                              right: 8.0,
                              child: IconButton(
                                onPressed: () {
                                  _showEditSceneScreen(context);
                                },
                                icon: const Icon(Icons.edit_outlined, color: Colors.white, shadows: [_smallShadow]),
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildSceneImage(BuildContext context) {
    if (scene.isSelected && scene.scene.imagePath == null) {
      return Image.asset('assets/images/scenes/scene-default-noimage.jpg', fit: BoxFit.cover, width: double.infinity);
    }
    if (!scene.isSelected && scene.scene.imagePath == null) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.black.withAlpha(128), BlendMode.srcATop),
        child: Image.asset('assets/images/scenes/scene-default-noimage.jpg', fit: BoxFit.cover, width: double.infinity),
      );
    }
    if (scene.isSelected && scene.scene.imagePath != null) {
      return Image.file(File(scene.scene.imagePath!), fit: BoxFit.cover, width: double.infinity);
    }
    if (!scene.isSelected && scene.scene.imagePath != null) {
      return ColorFiltered(
        colorFilter: ColorFilter.mode(Colors.black.withAlpha(97), BlendMode.srcATop),
        child: Image.file(File(scene.scene.imagePath!), fit: BoxFit.cover, width: double.infinity),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildSceneInfo(BuildContext context) {
    return Positioned(
      left: 16,
      bottom: 16,
      child: Row(
        children: [
          Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                scene.name,
                textAlign: TextAlign.start,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: Colors.white,
                  shadows: [Shadow(offset: const Offset(2.0, 2.0), blurRadius: 4.0, color: Colors.black.withAlpha(97))],
                ),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(
                    context.translate('{0} devices', pArgs: ['${scene.totalDeviceCount}']),
                    textAlign: TextAlign.start,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white, shadows: const [_smallShadow]),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.circle, size: 4, color: Colors.white, shadows: [_smallShadow]),
                  const SizedBox(width: 8),
                  Text(
                    context.translate('{0} active', pArgs: ['${scene.activeDeviceCount}']),
                    textAlign: TextAlign.start,
                    style: Theme.of(
                      context,
                    ).textTheme.bodyMedium?.copyWith(color: Colors.white, shadows: const [_smallShadow]),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _showEditSceneScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SceneEditScreen(args: SceneEditArguments(isCreation: false, model: scene.scene)),
      ),
    );
  }
}
