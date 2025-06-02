import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class PowerSwitchTile extends StatelessWidget {
  const PowerSwitchTile({super.key});

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
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                  child: Row(
                    key: ValueKey(isOn),
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        alignment: Alignment.center,
                        child:
                            isOn
                                ? Container(
                                  decoration: BoxDecoration(shape: BoxShape.circle, color: theme.colorScheme.secondary),
                                )
                                : Icon(Icons.power_settings_new, size: 20, color: Colors.red),
                      ),
                      const SizedBox(width: 12),
                      if (isOn)
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            SizedBox(
                              width: 40,
                              height: 40,
                              child: CircularProgressIndicator(
                                value: brightness / 100.0,
                                strokeWidth: 5,
                                backgroundColor: theme.colorScheme.outlineVariant,
                                valueColor: AlwaysStoppedAnimation<Color>(theme.colorScheme.primary),
                              ),
                            ),
                          ],
                        ),
                      if (isOn) const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              isOn ? 'ON' : 'OFF',
                              style: theme.textTheme.titleLarge?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            if (isOn)
                              Text(
                                '$brightness%',
                                style: theme.textTheme.labelMedium?.copyWith(color: theme.colorScheme.primary),
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
