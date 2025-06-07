import 'package:borneo_app/devices/borneo/lyfi/views/dashboard/toufu_view.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';

class DashboardPowerTile extends StatelessWidget {
  const DashboardPowerTile({super.key});

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
                    if (vm.canMeasurePower)
                      ...() {
                        final double watts = vm.currentWatts;
                        final int intPart = watts.floor();
                        final int decimalPart = ((watts - intPart) * 10).round();
                        final bool isZero = watts == 0;
                        return [
                          Text(
                            isZero ? '0' : intPart.toString(),
                            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                              color: Theme.of(context).colorScheme.primary,
                              fontFeatures: [FontFeature.tabularFigures()],
                              fontSize: 23,
                            ),
                          ),
                          if (!isZero) ...[
                            Text(
                              '.',
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                                fontFeatures: [FontFeature.tabularFigures()],
                                fontSize: 23,
                              ),
                            ),
                            Text(
                              decimalPart.toString(),
                              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                fontFeatures: [FontFeature.tabularFigures()],
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 11,
                              ),
                            ),
                          ],
                          Text(
                            'W',
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontFeatures: [FontFeature.tabularFigures()],
                              color: Theme.of(context).colorScheme.primary,
                              fontSize: 11,
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
                          fontSize: 23,
                        ),
                      ),
                    ],
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
