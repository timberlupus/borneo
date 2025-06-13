import 'dart:io';

import 'package:borneo_app/view_models/scenes/scene_edit_view_model.dart';
import 'package:borneo_app/view_models/scenes/scene_summary_view_model.dart';
import 'package:borneo_app/view_models/scenes/scenes_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'scene_edit_screen.dart';

class SceneCard extends StatelessWidget {
  final SceneSummaryViewModel scene;
  static const _smallShadow = Shadow(offset: Offset(1.0, 1.0), blurRadius: 2.0, color: Color.fromARGB(128, 0, 0, 0));

  const SceneCard(this.scene, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: scene,
      builder: (context, child) => Card(
        margin: EdgeInsets.symmetric(vertical: 8),
        clipBehavior: Clip.antiAlias,
        borderOnForeground: true,
        elevation: 2,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        child: AspectRatio(
          aspectRatio: 16.0 / 9.0,
          child: Consumer<SceneSummaryViewModel>(
            builder: (context, vm, child) => InkWell(
              onTap: scene.isSelected
                  ? () {}
                  : () async {
                      final scenesVM = context.read<ScenesViewModel>();
                      await scenesVM.switchCurrentScene(scene.id);
                    },
              child: Ink(
                decoration: BoxDecoration(
                  color: scene.isSelected
                      ? Theme.of(context).colorScheme.primaryContainer
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(16.0),
                ),
                child: scene.isSelected
                    ? Stack(
                        alignment: Alignment.topRight,
                        children: [
                          if (scene.isSelected && vm.model.imagePath == null)
                            Image.asset(
                              'assets/images/scenes/scene-default-noimage.jpg',
                              fit: BoxFit.cover,
                              width: double.infinity,
                            ),
                          if (!scene.isSelected && vm.model.imagePath == null)
                            ColorFiltered(
                              colorFilter: ColorFilter.mode(Colors.black.withAlpha(128), BlendMode.srcATop),
                              child: Image.asset(
                                'assets/images/scenes/scene-default-noimage.jpg',
                                fit: BoxFit.cover,
                                width: double.infinity,
                              ),
                            ),
                          if (scene.isSelected && vm.model.imagePath != null)
                            Image.file(File(vm.model.imagePath!), fit: BoxFit.cover, width: double.infinity),
                          if (!scene.isSelected && vm.model.imagePath != null)
                            ColorFiltered(
                              colorFilter: ColorFilter.mode(Colors.black.withAlpha(97), BlendMode.srcATop),
                              child: Image.file(File(vm.model.imagePath!), fit: BoxFit.cover, width: double.infinity),
                            ),
                          Positioned(
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
                                      style: TextStyle(
                                        fontSize: 26,
                                        color: Colors.white,
                                        shadows: [
                                          Shadow(
                                            offset: Offset(2.0, 2.0),
                                            blurRadius: 4.0,
                                            color: Colors.black.withAlpha(97),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          '${scene.totalDeviceCount} devices',
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                            shadows: const [_smallShadow],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Icon(Icons.circle, size: 4, color: Colors.white, shadows: const [_smallShadow]),
                                        const SizedBox(width: 8),
                                        Text(
                                          '${scene.activeDeviceCount} active',
                                          textAlign: TextAlign.start,
                                          style: TextStyle(
                                            fontSize: 14,
                                            color: Colors.white,
                                            shadows: const [_smallShadow],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          if (scene.isSelected)
                            Positioned.fill(
                              child: ShaderMask(
                                shaderCallback: (Rect bounds) {
                                  return RadialGradient(
                                    center: Alignment.center,
                                    radius: 0.5,
                                    colors: [Colors.white.withAlpha(200), Colors.white],
                                    stops: [0.0, 1.0],
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
                              icon: Icon(Icons.edit_outlined, color: Colors.white, shadows: const [_smallShadow]),
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
                                if (scene.isSelected && vm.model.imagePath == null)
                                  Image.asset(
                                    'assets/images/scenes/scene-default-noimage.jpg',
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                  ),
                                if (!scene.isSelected && vm.model.imagePath == null)
                                  ColorFiltered(
                                    colorFilter: ColorFilter.mode(Colors.black.withAlpha(128), BlendMode.srcATop),
                                    child: Image.asset(
                                      'assets/images/scenes/scene-default-noimage.jpg',
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                if (scene.isSelected && vm.model.imagePath != null)
                                  Image.file(File(vm.model.imagePath!), fit: BoxFit.cover, width: double.infinity),
                                if (!scene.isSelected && vm.model.imagePath != null)
                                  ColorFiltered(
                                    colorFilter: ColorFilter.mode(Colors.black.withAlpha(97), BlendMode.srcATop),
                                    child: Image.file(
                                      File(vm.model.imagePath!),
                                      fit: BoxFit.cover,
                                      width: double.infinity,
                                    ),
                                  ),
                                Positioned(
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
                                            style: TextStyle(
                                              fontSize: 26,
                                              color: Colors.white,
                                              shadows: [
                                                Shadow(
                                                  offset: Offset(2.0, 2.0),
                                                  blurRadius: 4.0,
                                                  color: Colors.black.withAlpha(97),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Row(
                                            children: [
                                              Text(
                                                '${scene.totalDeviceCount} devices',
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  shadows: const [_smallShadow],
                                                ),
                                              ),
                                              const SizedBox(width: 8),
                                              Icon(
                                                Icons.circle,
                                                size: 4,
                                                color: Colors.white,
                                                shadows: const [_smallShadow],
                                              ),
                                              const SizedBox(width: 8),
                                              Text(
                                                '${scene.activeDeviceCount} active',
                                                textAlign: TextAlign.start,
                                                style: TextStyle(
                                                  fontSize: 14,
                                                  color: Colors.white,
                                                  shadows: const [_smallShadow],
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (scene.isSelected)
                                  Positioned.fill(
                                    child: ShaderMask(
                                      shaderCallback: (Rect bounds) {
                                        return RadialGradient(
                                          center: Alignment.center,
                                          radius: 0.5,
                                          colors: [Colors.white.withAlpha(200), Colors.white],
                                          stops: [0.0, 1.0],
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
                                    icon: Icon(Icons.edit_outlined, color: Colors.white, shadows: const [_smallShadow]),
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
        ),
      ),
    );
  }

  Future<void> _showEditSceneScreen(BuildContext context) async {
    final vm = context.read<SceneSummaryViewModel>();
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => SceneEditScreen(args: SceneEditArguments(isCreation: false, model: vm.model)),
      ),
    );
  }
}
