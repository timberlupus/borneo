import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import 'dart:ui';

class DashboardFanTile extends StatelessWidget {
  const DashboardFanTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({double fanPowerRatio})>(
      selector: (_, vm) => (fanPowerRatio: vm.fanPowerRatio),
      builder:
          (context, vm, _) => DashboardToufu(
            title: 'Fan',
            icon: Icons.air,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            arcColor: Theme.of(context).colorScheme.outlineVariant,
            progressColor: Theme.of(context).colorScheme.secondary,
            minValue: 0,
            maxValue: 100,
            value: vm.fanPowerRatio,
            center: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              mainAxisAlignment: MainAxisAlignment.center,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  '${vm.fanPowerRatio.toInt()}',
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontSize: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                Text(
                  '%',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontSize: 12,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
    );
  }
}
