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
      builder: (context, child) => Card.filled(
        margin: EdgeInsets.all(0),
        elevation: 0,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: LayoutBuilder(
                    builder:
                        (BuildContext context, BoxConstraints constraints) {
                      final iconSize = constraints.maxHeight - 16.0;
                      return Align(
                        alignment: Alignment.centerLeft,
                        child: SvgPicture.asset(
                          viewModel.iconAssetPath,
                          height: iconSize,
                          width: iconSize,
                        ),
                      );
                    },
                  ),
                ),
                Selector<RoutineSummaryViewModel, String>(
                  selector: (context, vm) => vm.name,
                  builder: (_, routineName, child) => Text(
                    routineName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 14.0),
                  ),
                ),
                Divider(height: 16, thickness: 1),
                Row(mainAxisSize: MainAxisSize.max, children: [
                  if (viewModel.isActive)
                    Text(context.translate('ACTIVE'),
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor)),
                  if (!viewModel.isActive)
                    Text(context.translate('INACTIVE'),
                        style: TextStyle(
                            fontSize: 12, color: Theme.of(context).hintColor)),
                  Spacer(),
                  Switch(
                      value: false,
                      /*
                      activeColor: Colors.white,
                      activeTrackColor: Theme.of(context).primaryColor,
                      inactiveThumbColor: Theme.of(context).primaryColor,
                      inactiveTrackColor:
                          Theme.of(context).colorScheme.surfaceBright,
                      trackOutlineColor:
                          WidgetStateProperty.resolveWith<Color?>(
                              (Set<WidgetState> states) => Colors.transparent),
                          */
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      onChanged: (v) {}),
                ]),
              ]),
        ),
      ),
    );
  }
}
