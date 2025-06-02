import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gauge_indicator/gauge_indicator.dart';
import 'dart:ui';

class TemperatureTile extends StatelessWidget {
  const TemperatureTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({int? currentTemp, double currentTempRatio})>(
      selector: (_, vm) => (currentTemp: vm.currentTemp, currentTempRatio: vm.currentTempRatio),
      builder:
          (context, vm, _) => DashboardToufu(
            title: 'Temperature',
            icon: Icons.thermostat,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            arcColor: null,
            progressColor: switch (vm.currentTemp) {
              != null && <= 45 => Theme.of(context).primaryColor,
              != null && > 45 && < 65 => Theme.of(context).colorScheme.secondary,
              != null && >= 65 => Theme.of(context).colorScheme.error,
              null || int() => Colors.grey,
            },
            value: vm.currentTemp?.toDouble() ?? 0.0,
            minValue: 0,
            maxValue: 105,
            center: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              mainAxisAlignment: MainAxisAlignment.center,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(
                  vm.currentTemp != null ? '${vm.currentTemp}' : "N/A",
                  style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: Theme.of(context).colorScheme.primary,
                    fontSize: 24,
                  ),
                ),
                if (vm.currentTemp != null)
                  Text(
                    '℃',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: Theme.of(context).colorScheme.primary,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            segments: [
              GaugeSegment(from: 0, to: 45, color: Colors.green[100]!),
              GaugeSegment(from: 45, to: 65, color: Colors.orange[100]!),
              GaugeSegment(from: 65, to: 105, color: Colors.red[100]!),
            ],
          ),
    );
  }
}
