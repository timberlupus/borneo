import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../widgets/rolling_integer.dart';

class DashboardFanTile extends StatelessWidget {
  const DashboardFanTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<LyfiViewModel, ({bool isOnline, double? fanPowerRatio})>(
      selector: (_, vm) => (isOnline: vm.isOnline, fanPowerRatio: vm.fanPowerRatio),
      builder: (context, vm, _) => DashboardToufu(
        title: context.translate("Fan"),
        icon: Icons.air,
        foregroundColor: theme.colorScheme.onSurface,
        backgroundColor: theme.colorScheme.surfaceContainerHighest,
        arcColor: theme.colorScheme.outlineVariant,
        progressColor: theme.colorScheme.secondary,
        minValue: 0,
        maxValue: 100,
        value: vm.fanPowerRatio ?? 0,
        center: Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          mainAxisAlignment: MainAxisAlignment.center,
          textBaseline: TextBaseline.alphabetic,
          children: vm.isOnline && vm.fanPowerRatio != null
              ? [
                  RollingInteger(
                    value: vm.fanPowerRatio!.toInt(),
                    textStyle: theme.textTheme.headlineLarge?.copyWith(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 24,
                      color: theme.colorScheme.primary,
                    ),
                    duration: const Duration(milliseconds: 300),
                  ),
                  Text(
                    '%',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontFeatures: [FontFeature.tabularFigures()],
                      fontSize: 12,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ]
              : [
                  Text(
                    context.translate("N/A"),
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: theme.colorScheme.outlineVariant,
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
        ),
      ),
    );
  }
}
