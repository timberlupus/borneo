import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../widgets/rolling_integer.dart';

class DashboardPowerTile extends StatelessWidget {
  const DashboardPowerTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<
      LyfiViewModel,
      ({bool isOnline, bool isOn, bool canMeasureVoltage, bool canMeasureCurrent, bool canMeasurePower})
    >(
      selector: (_, vm) => (
        isOnline: vm.isOnline,
        isOn: vm.isOn,
        canMeasureVoltage: vm.canMeasureVoltage,
        canMeasureCurrent: vm.canMeasureCurrent,
        canMeasurePower: vm.canMeasurePower,
      ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final vm = context.read<LyfiViewModel>();
        final mergedListenable = Listenable.merge([vm.currentVoltage, vm.currentCurrent, vm.currentWatts]);
        final bool isOnline = props.isOnline;
        final disabledColor = theme.colorScheme.onSurface.withValues(alpha: 0.38);
        final Color fgColor = theme.colorScheme.onSurface;
        final Color arcColor = theme.colorScheme.outlineVariant;
        final Color progressColor = isOnline ? theme.colorScheme.tertiary : disabledColor;
        final Color textPrimary = theme.colorScheme.primary;
        final Color textOnSurface = theme.colorScheme.onSurface;
        return ListenableBuilder(
          listenable: mergedListenable,
          builder: (context, _) => DashboardToufu(
            title: context.translate("LED Power"),
            icon: Icons.power_outlined,
            foregroundColor: fgColor,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
            arcColor: arcColor,
            progressColor: progressColor,
            minValue: 0.0,
            maxValue: isOnline ? vm.nominalPower ?? 99999 : 99999,
            value: props.canMeasurePower && isOnline ? vm.currentWatts.value ?? 0 : 0,
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
                    if (props.canMeasurePower && isOnline)
                      ...() {
                        final double watts = vm.currentWatts.value!;
                        final int intPart = watts.floor();
                        final String decimalStr = watts.toStringAsFixed(1).split('.')[1];
                        final bool isZero = watts == 0;
                        return [
                          RollingInteger(
                            value: isZero ? 0 : intPart,
                            textStyle: theme.textTheme.titleLarge?.copyWith(
                              color: textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                            duration: const Duration(milliseconds: 300),
                          ),
                          if (!isZero) ...[
                            Text(
                              '.',
                              style: theme.textTheme.titleSmall?.copyWith(
                                color: textPrimary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              decimalStr,
                              style: theme.textTheme.titleSmall?.copyWith(
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: textPrimary,
                              ),
                            ),
                          ],
                          Text(
                            'W',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: textPrimary,
                            ),
                          ),
                        ];
                      }()
                    else ...[
                      Text(
                        context.translate("N/A"),
                        style: theme.textTheme.titleLarge?.copyWith(
                          color: theme.colorScheme.outlineVariant,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
                if (props.canMeasurePower && isOnline) const Divider(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (props.canMeasureVoltage && isOnline)
                      Text(
                        '${vm.currentVoltage.value!.toStringAsFixed(1)}V',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textOnSurface,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (props.canMeasureCurrent && isOnline) const SizedBox(width: 4),
                    if (props.canMeasureCurrent && isOnline)
                      Text("·", style: theme.textTheme.bodySmall?.copyWith(color: textOnSurface)),
                    if (props.canMeasureCurrent && isOnline) const SizedBox(width: 4),
                    if (vm.canMeasureCurrent && isOnline)
                      Text(
                        '${vm.currentCurrent.value!.toStringAsFixed(1)}A',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: textOnSurface,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// rolling integer moved to widgets/rolling_integer.dart
