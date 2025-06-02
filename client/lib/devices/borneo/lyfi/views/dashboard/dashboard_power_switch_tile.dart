import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:gauge_indicator/gauge_indicator.dart';
import '../../view_models/lyfi_view_model.dart';

class DashboardPowerSwitchTile extends StatelessWidget {
  const DashboardPowerSwitchTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<LyfiViewModel, ({bool isOn, bool isBusy, bool isLocked, double overallBrightness, bool canUnlock})>(
      selector:
          (_, vm) => (
            isOn: vm.isOn,
            isBusy: vm.isBusy,
            isLocked: vm.isLocked,
            overallBrightness: vm.overallBrightness,
            canUnlock: vm.canUnlock,
          ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isOn = props.isOn;
        final brightness = (props.overallBrightness * 100).clamp(0, 100).toInt();
        return AspectRatio(
          aspectRatio: 2.0,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(16),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap:
                  (!props.isBusy && props.isLocked)
                      ? () => context.read<LyfiViewModel>().switchPowerOnOff(!isOn)
                      : null,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: Row(
                    key: ValueKey(isOn),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      if (!isOn)
                        Expanded(
                          flex: 0,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: FittedBox(
                              fit: BoxFit.contain,
                              child: Icon(Icons.power_settings_new, color: Colors.red),
                            ),
                          ),
                        ),
                      if (isOn)
                        Expanded(
                          flex: 0,
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Container(
                              margin: EdgeInsets.all(4),
                              child: AnimatedRadialGauge(
                                initialValue: 0,
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.decelerate,
                                value: brightness.toDouble(),
                                radius: null,
                                axis: GaugeAxis(
                                  min: 0,
                                  max: 100,
                                  degrees: 270,
                                  style: GaugeAxisStyle(
                                    thickness: 8,
                                    segmentSpacing: 0,
                                    background: theme.colorScheme.outlineVariant,
                                    cornerRadius: Radius.zero,
                                  ),
                                  pointer: null,
                                  progressBar: GaugeProgressBar.basic(color: theme.colorScheme.primary),
                                  segments: const [],
                                ),
                                builder: (context, label, value) => const SizedBox.shrink(),
                                child: null,
                              ),
                            ),
                          ),
                        ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOn ? 'ON' : 'OFF',
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: isOn ? Colors.green : Colors.red,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isOn)
                              Row(
                                mainAxisSize: MainAxisSize.max,
                                children: [
                                  Text(
                                    '$brightness%',
                                    style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.primary),
                                  ),
                                ],
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
