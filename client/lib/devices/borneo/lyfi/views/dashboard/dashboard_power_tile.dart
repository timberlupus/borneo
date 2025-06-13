import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
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
        return ListenableBuilder(
          listenable: mergedListenable,
          builder: (context, _) => DashboardToufu(
            title: 'LED Power',
            icon: Icons.power_outlined,
            foregroundColor: Theme.of(context).colorScheme.onSurface,
            backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
            arcColor: Theme.of(context).colorScheme.outlineVariant,
            progressColor: Theme.of(context).colorScheme.tertiary,
            minValue: 0.0,
            maxValue: props.isOnline ? vm.nominalPower ?? 99999 : 99999,
            value: props.canMeasurePower ? vm.currentWatts.value ?? 0 : 0,
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
                    if (props.canMeasurePower)
                      ...() {
                        final double watts = vm.currentWatts.value!;
                        final int intPart = watts.floor();
                        final int decimalPart = ((watts - intPart) * 10).round();
                        final bool isZero = watts == 0;
                        return [
                          Text(
                            isZero ? '0' : intPart.toString(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          if (!isZero) ...[
                            Text(
                              '.',
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontFeatures: [FontFeature.tabularFigures()],
                              ),
                            ),
                            Text(
                              decimalPart.toString(),
                              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                          Text(
                            'W',
                            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ];
                      }()
                    else ...[
                      Text(
                        'N/A',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          color: Theme.of(context).colorScheme.primary,
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
                    if (props.canMeasureVoltage)
                      Text(
                        '${vm.currentVoltage.value!.toStringAsFixed(1)}V',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurface,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    if (props.canMeasureCurrent) const SizedBox(width: 4),
                    if (props.canMeasureCurrent)
                      Text(
                        "·",
                        style: Theme.of(
                          context,
                        ).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurface),
                      ),
                    if (props.canMeasureCurrent) const SizedBox(width: 4),
                    if (vm.canMeasureCurrent)
                      Text(
                        '${vm.currentCurrent.value!.toStringAsFixed(1)}A',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
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
      },
    );
  }
}
