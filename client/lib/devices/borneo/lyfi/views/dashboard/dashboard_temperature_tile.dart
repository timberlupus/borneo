import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import 'package:gauge_indicator/gauge_indicator.dart';
import '../widgets/rolling_integer.dart';

class DashboardTemperatureTile extends StatelessWidget {
  const DashboardTemperatureTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final greenBg = isDark ? Colors.green[800]!.withValues(alpha: 0.38) : Colors.green[100]!;
    final yellowBg = isDark ? Colors.amber[800]!.withValues(alpha: 0.38) : Colors.amber[100]!;
    final redBg = isDark ? Colors.red[800]!.withValues(alpha: 0.38) : Colors.red[100]!;

    final (isOnline, currentTempRaw, currentTemp, temperatureUnitText) = context
        .select<LyfiViewModel, (bool, int?, int?, String)>(
          (vm) => (vm.isOnline, vm.currentTempRaw, vm.currentTemp, vm.localeService.temperatureUnitText),
        );

    Color progressColor;
    if (currentTempRaw != null && currentTempRaw <= 45) {
      progressColor = Colors.lightGreen;
    } else if (currentTempRaw != null && currentTempRaw > 45 && currentTempRaw < 65) {
      progressColor = theme.colorScheme.secondary;
    } else if (currentTempRaw != null && currentTempRaw >= 65) {
      progressColor = theme.colorScheme.error;
    } else {
      progressColor = theme.disabledColor;
    }

    return DashboardToufu(
      title: context.translate("Temperature"),
      icon: Icons.thermostat,
      foregroundColor: theme.colorScheme.onSurface,
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      arcColor: null,
      progressColor: progressColor,
      value: currentTempRaw?.toDouble() ?? 0.0,
      minValue: 0,
      maxValue: 105,
      center: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        mainAxisAlignment: MainAxisAlignment.center,
        textBaseline: TextBaseline.alphabetic,
        children: [
          if (isOnline && currentTemp != null)
            RollingInteger(
              value: currentTemp,
              textStyle: theme.textTheme.headlineLarge?.copyWith(
                fontFeatures: [FontFeature.tabularFigures()],
                color: progressColor,
                fontSize: 24,
              ),
              duration: const Duration(milliseconds: 360),
            )
          else
            Text(
              context.translate("N/A"),
              style: theme.textTheme.headlineLarge?.copyWith(
                fontFeatures: [FontFeature.tabularFigures()],
                color: theme.colorScheme.outlineVariant,
                fontSize: 24,
              ),
            ),
          if (isOnline && currentTemp != null)
            Text(
              temperatureUnitText,
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
    );
  }
}

// rolling integer moved to widgets/rolling_integer.dart
