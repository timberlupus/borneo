import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/view_models/routines/routine_summary_view_model.dart';

class RoutineCard extends StatelessWidget {
  final RoutineSummaryViewModel viewModel;
  const RoutineCard(this.viewModel, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: viewModel,
      builder: (context, child) {
        final colorScheme = Theme.of(context).colorScheme;
        return Consumer<RoutineSummaryViewModel>(
          builder: (context, vm, _) {
            final isBusy = vm.isBusy;
            final isActive = vm.isActive;
            final bgColor = isActive ? colorScheme.primaryContainer : colorScheme.surfaceContainer;
            final fgColor = isActive ? colorScheme.onPrimaryContainer : colorScheme.onSurface;
            return Stack(
              children: [
                Card.filled(
                  margin: EdgeInsets.all(0),
                  elevation: 0,
                  color: bgColor,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Column(
                      mainAxisSize: MainAxisSize.max,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: LayoutBuilder(
                            builder: (BuildContext context, BoxConstraints constraints) {
                              final iconSize = constraints.maxHeight - 16.0;
                              return Align(
                                alignment: Alignment.centerLeft,
                                child: SvgPicture.asset(vm.iconAssetPath, height: iconSize, width: iconSize),
                              );
                            },
                          ),
                        ),
                        Selector<RoutineSummaryViewModel, String>(
                          selector: (context, vm) => vm.name,
                          builder:
                              (_, routineName, child) => Text(
                                routineName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(fontSize: 14.0, color: fgColor),
                              ),
                        ),
                        Divider(height: 16, thickness: 1, color: fgColor.withValues(alpha: 0.2)),
                        Row(
                          mainAxisSize: MainAxisSize.max,
                          children: [
                            Text(
                              isActive ? context.translate('ACTIVE') : context.translate('INACTIVE'),
                              style: TextStyle(fontSize: 12, color: fgColor.withValues(alpha: 0.7)),
                            ),
                            Spacer(),
                            Switch(
                              value: isActive,
                              onChanged:
                                  isBusy
                                      ? null
                                      : (v) async {
                                        if (v) {
                                          await vm.executeRoutine();
                                        } else {
                                          await vm.undoRoutine();
                                        }
                                      },
                              activeColor: colorScheme.primary,
                              inactiveThumbColor: colorScheme.primary,
                              inactiveTrackColor: colorScheme.surfaceBright,
                              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isBusy)
                  Positioned.fill(
                    child: Container(
                      color: bgColor.withValues(alpha: 0.6),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  ),
              ],
            );
          },
        );
      },
    );
  }
}
