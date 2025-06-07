import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/view_models/scenes/scene_edit_view_model.dart';
import 'package:borneo_app/view_models/scenes/scenes_view_model.dart';
import '../routines/routine_list.dart';
import 'scene_card.dart';
import 'scene_edit_screen.dart';

class SceneList extends StatelessWidget {
  const SceneList({super.key});

  @override
  Widget build(BuildContext context) {
    //   final currentIndex = vm.scenes.indexWhere((x) => x.isCurrent);
    double screenHeight = MediaQuery.of(context).size.height;
    return SliverToBoxAdapter(
      child: Consumer<ScenesViewModel>(
        builder:
            (context, vm, child) => Container(
              padding: EdgeInsets.all(0),
              height: screenHeight / 4.0,
              child: ListView.separated(
                padding: EdgeInsets.symmetric(horizontal: 16),
                separatorBuilder: (_, _) => const SizedBox(width: 16),
                scrollDirection: Axis.horizontal,
                itemCount: vm.scenes.length,
                itemBuilder: (context, index) {
                  return SceneCard(vm.scenes[index]);
                },
              ),
            ),
      ),
    );
  }
}

class ScenesScreen extends StatelessWidget {
  const ScenesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.read<ScenesViewModel>();

    return FutureBuilder(
      future: vm.initFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(body: Center(child: CircularProgressIndicator()));
        } else if (snapshot.hasError) {
          return Scaffold(
            body: Center(
              child: Text(context.translate('Error: {errMsg}', nArgs: {'errMsg': snapshot.error.toString()})),
            ),
          );
        } else {
          return Scaffold(
            body: CustomScrollView(
              slivers: [
                SliverAppBar(
                  title: Text(context.translate('Scenes')),
                  actions: [IconButton(icon: Icon(Icons.add_outlined), onPressed: () => _showNewSceneScreen(context))],
                ),
                SceneList(),
                RoutineList(),
              ],
            ),
          );
        }
      },
    );
  }

  Future<void> _showNewSceneScreen(BuildContext context) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => SceneEditScreen(args: SceneEditArguments(isCreation: true))),
    );
  }
}
