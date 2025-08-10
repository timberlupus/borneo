import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';

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
        final vm = context.read<LyfiViewModel>();
        final mergedListenable = Listenable.merge([vm.currentVoltage, vm.currentCurrent, vm.currentWatts]);
        final bool isOnline = props.isOnline;
        final Color disabledColor = Theme.of(context).disabledColor;
        final Color fgColor = Theme.of(context).colorScheme.onSurface;
        final Color bgColor = isOnline
            ? Theme.of(context).colorScheme.surfaceContainerHighest
            : Theme.of(context).colorScheme.surfaceContainerLow;
        final Color arcColor = isOnline ? Theme.of(context).colorScheme.outlineVariant : disabledColor;
        final Color progressColor = isOnline ? Theme.of(context).colorScheme.tertiary : disabledColor;
        final Color textPrimary = Theme.of(context).colorScheme.primary;
        final Color textOnSurface = Theme.of(context).colorScheme.onSurface;
        return ListenableBuilder(
          listenable: mergedListenable,
          builder: (context, _) => DashboardToufu(
            title: context.translate("LED Power"),
            icon: Icons.power_outlined,
            foregroundColor: fgColor,
            backgroundColor: bgColor,
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
                        final int decimalPart = ((watts - intPart) * 10).round();
                        final bool isZero = watts == 0;
                        return [
                          Text(
                            isZero ? '0' : intPart.toString(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: textPrimary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (!isZero) ...[
                            Text(
                              '.',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: textPrimary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              decimalPart.toString(),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: textPrimary,
                              ),
                            ),
                          ],
                          Text(
                            'W',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: textPrimary,
                            ),
                          ),
                        ];
                      }()
                    else ...[
                      Text(
                        context.translate("N/A"),
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: textPrimary,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (props.canMeasureVoltage && isOnline)
                      Text(
                        '${vm.currentVoltage.value!.toStringAsFixed(1)}V',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: textOnSurface,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (props.canMeasureCurrent && isOnline) const SizedBox(width: 4),
                    if (props.canMeasureCurrent && isOnline)
                      Text("·", style: Theme.of(context).textTheme.bodySmall?.copyWith(color: textOnSurface)),
                    if (props.canMeasureCurrent && isOnline) const SizedBox(width: 4),
                    if (vm.canMeasureCurrent && isOnline)
                      Text(
                        '${vm.currentCurrent.value!.toStringAsFixed(1)}A',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
