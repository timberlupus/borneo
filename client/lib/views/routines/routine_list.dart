import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/views/routines/routine_card.dart';
import 'package:borneo_app/view_models/scenes/scenes_view_model.dart';

class RoutineList extends StatelessWidget {
  const RoutineList({super.key});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<ScenesViewModel>();
    return SliverToBoxAdapter(
      child: Container(
        padding: EdgeInsets.fromLTRB(16, 16, 16, 24),
        child: Column(
          mainAxisSize: MainAxisSize.max,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(context.translate('Routines'), style: Theme.of(context).textTheme.titleMedium),
            SizedBox(height: 16),
            AnimatedBuilder(
              animation: Listenable.merge([vm.isRoutinesLoading, vm.routines]),
              builder: (context, _) {
                if (vm.isRoutinesLoading.value) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: CircularProgressIndicator(),
                    ),
                  );
                }
                final routines = vm.routines.value;
                if (routines.isEmpty) {
                  return Center(
                    child: Padding(
                      padding: EdgeInsets.symmetric(vertical: 32),
                      child: Text(context.translate('No routines'), style: TextStyle(color: Colors.grey)),
                    ),
                  );
                }
                return AnimatedSwitcher(
                  duration: Duration(milliseconds: 500),
                  child: GridView.builder(
                    key: ValueKey(routines.length),
                    shrinkWrap: true,
                    primary: true,
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 16.0,
                      mainAxisSpacing: 16.0,
                    ),
                    padding: EdgeInsets.all(0.0),
                    itemCount: routines.length,
                    itemBuilder: (context, index) {
                      if (index < routines.length) {
                        return RoutineCard(routines[index]);
                      } else {
                        return _buildAddItem(context);
                      }
                    },
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  /// 'Adding' routine item
  Widget _buildAddItem(BuildContext context) {
    return GestureDetector(
      onTap: () {
        //
      },
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.black12, width: 1.0),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.add_outlined, size: 64.0),
            SizedBox(width: 8.0),
            Text(context.translate('New Routine'), style: TextStyle(fontSize: 12.0)),
          ],
        ),
      ),
    );
  }
}
