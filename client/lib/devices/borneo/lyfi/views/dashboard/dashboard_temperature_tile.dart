import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import 'package:gauge_indicator/gauge_indicator.dart';
import 'dart:ui';

class DashboardTemperatureTile extends StatelessWidget {
  const DashboardTemperatureTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    // 背景分段色：亮色用很浅，暗色用更深且加透明度
    final greenBg = isDark ? Colors.green[800]!.withValues(alpha: 0.38) : Colors.green[100]!;
    final yellowBg = isDark ? Colors.amber[800]!.withValues(alpha: 0.38) : Colors.amber[100]!;
    final redBg = isDark ? Colors.red[800]!.withValues(alpha: 0.38) : Colors.red[100]!;

    // 当前进度色：和原来一样，主题色
    Color progressColor;
    final temp = context.select<LyfiViewModel, int?>((vm) => vm.currentTemp);
    if (temp != null && temp <= 45) {
      progressColor = theme.colorScheme.primary;
    } else if (temp != null && temp > 45 && temp < 65) {
      progressColor = theme.colorScheme.secondary;
    } else if (temp != null && temp >= 65) {
      progressColor = theme.colorScheme.error;
    } else {
      progressColor = theme.disabledColor;
    }

    return Consumer<LyfiViewModel>(
      builder:
          (context, vm, _) => DashboardToufu(
            title: 'Temperature',
            icon: Icons.thermostat,
            foregroundColor: theme.colorScheme.onSurface,
            backgroundColor: theme.colorScheme.surfaceContainer,
            arcColor: null,
            progressColor: progressColor,
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
                  style: theme.textTheme.headlineLarge?.copyWith(
                    fontFeatures: [FontFeature.tabularFigures()],
                    color: progressColor,
                    fontSize: 24,
                  ),
                ),
                if (vm.currentTemp != null)
                  Text(
                    '℃',
                    style: theme.textTheme.labelMedium?.copyWith(
                      fontFeatures: [FontFeature.tabularFigures()],
                      color: progressColor,
                      fontSize: 12,
                    ),
                  ),
              ],
            ),
            segments: [
              GaugeSegment(from: 0, to: 45, color: greenBg),
              GaugeSegment(from: 45, to: 65, color: yellowBg),
              GaugeSegment(from: 65, to: 105, color: redBg),
            ],
          ),
    );
  }
}
