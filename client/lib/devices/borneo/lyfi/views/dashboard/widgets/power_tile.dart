import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'dart:ui';

class PowerTile extends StatelessWidget {
  const PowerTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<LyfiViewModel>(
      builder:
          (context, vm, _) => DashboardToufu(
            title: 'Power',
            icon: Icons.power_outlined,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            arcColor: Theme.of(context).colorScheme.outlineVariant,
            progressColor: Theme.of(context).colorScheme.tertiary,
            minValue: 0.0,
            maxValue: vm.lyfiDeviceInfo.nominalPower ?? 9999,
            value: vm.isOn ? vm.currentWatts : 0,
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              mainAxisSize: MainAxisSize.max,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  mainAxisAlignment: MainAxisAlignment.center,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      vm.canMeasurePower ? vm.currentWatts.toStringAsFixed(0) : "N/A",
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        color: Theme.of(context).colorScheme.primary,
                        fontFeatures: [FontFeature.tabularFigures()],
                        fontSize: 23,
                      ),
                    ),
                    if (vm.canMeasurePower)
                      Text(
                        'W',
                        style: Theme.of(context).textTheme.labelMedium?.copyWith(
                          fontFeatures: [FontFeature.tabularFigures()],
                          color: Theme.of(context).colorScheme.primary,
                          fontSize: 11,
                        ),
                      ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (vm.canMeasureVoltage)
                      Text(
                        '${vm.borneoDeviceStatus!.powerVoltage!.toStringAsFixed(1)}V',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (vm.canMeasureCurrent) SizedBox(width: 4),
                    if (vm.canMeasureCurrent)
                      Text(
                        '${vm.borneoDeviceStatus!.powerCurrent!.toStringAsFixed(1)}A',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
    );
  }
}
