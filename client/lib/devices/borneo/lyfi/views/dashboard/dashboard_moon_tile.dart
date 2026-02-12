import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';
import 'package:community_material_icon/community_material_icon.dart';
import '../../view_models/lyfi_view_model.dart';
import '../moon_screen.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';

String getMoonPhaseName(double angle) => switch (angle) {
  _ when angle < 22.5 || angle >= 337.5 => 'New Moon',
  _ when angle < 67.5 => 'Waxing Crescent',
  _ when angle < 112.5 => 'First Quarter',
  _ when angle < 157.5 => 'Waxing Gibbous',
  _ when angle < 202.5 => 'Full Moon',
  _ when angle < 247.5 => 'Waning Gibbous',
  _ when angle < 292.5 => 'Last Quarter',
  _ => 'Waning Crescent',
};

IconData getMoonPhaseIcon(double angle) => switch (angle) {
  _ when angle < 22.5 || angle >= 337.5 => CommunityMaterialIcons.moon_new,
  _ when angle < 67.5 => CommunityMaterialIcons.moon_waxing_crescent,
  _ when angle < 112.5 => CommunityMaterialIcons.moon_first_quarter,
  _ when angle < 157.5 => CommunityMaterialIcons.moon_waxing_gibbous,
  _ when angle < 202.5 => CommunityMaterialIcons.moon_full,
  _ when angle < 247.5 => CommunityMaterialIcons.moon_waning_gibbous,
  _ when angle < 292.5 => CommunityMaterialIcons.moon_last_quarter,
  _ => CommunityMaterialIcons.moon_waning_crescent,
};

class DashboardMoonTile extends StatelessWidget {
  const DashboardMoonTile({super.key});

  @override
  Widget build(BuildContext context) {
    return Selector<
      LyfiViewModel,
      ({
        bool isOnline,
        bool isOn,
        bool enabled,
        MoonStatus? moonStatus,
        bool isMoonTime,
        double currentSunBrightness,
        String? nextMoonTime,
      })
    >(
      selector: (_, vm) => (
        isOnline: vm.isOnline,
        isOn: vm.isOn,
        enabled: vm.lyfiThing.getProperty<MoonConfig>('moonConfig')?.enabled ?? false,
        moonStatus: vm.lyfiThing.getProperty<MoonStatus>('moonStatus'),
        isMoonTime: vm.isMoonTime,
        currentSunBrightness: vm.currentSunBrightness,
        nextMoonTime: vm.nextMoonTime,
      ),
      builder: (context, props, _) {
        final theme = Theme.of(context);
        final isMoonActive = props.enabled && props.moonStatus != null && props.isMoonTime;
        final moonStatus = props.moonStatus;
        final isDisabled = !props.isOnline || !props.isOn;
        final Color bgColor = isMoonActive
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainerHighest;
        final Color fgColor = isMoonActive ? theme.colorScheme.onPrimaryContainer : theme.colorScheme.onSurface;
        final double disabledAlpha = 0.38;
        final Color effectiveFgColor = isDisabled ? fgColor.withValues(alpha: disabledAlpha) : fgColor;
        final Color iconColor = isMoonActive ? theme.colorScheme.onPrimary : theme.colorScheme.primary;
        final Color effectiveIconColor = isDisabled ? iconColor.withValues(alpha: disabledAlpha) : iconColor;
        final String title = context.translate('Moonlight');
        final IconData iconData = isMoonActive && moonStatus != null
            ? getMoonPhaseIcon(moonStatus.phaseAngle)
            : Icons.dark_mode_outlined;
        final String subtitle = isMoonActive && moonStatus != null
            ? '${moonStatus.illumination.toStringAsFixed(0)}%'
            : props.nextMoonTime != null
            ? '${context.translate('Rises at')} ${props.nextMoonTime!}'
            : context.translate('Daytime');
        return AspectRatio(
          aspectRatio: 2.0,
          child: Container(
            decoration: BoxDecoration(color: bgColor, borderRadius: BorderRadius.circular(16)),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: props.isOnline && props.isOn
                    ? () async {
                        if (context.mounted) {
                          final vm = context.read<LyfiViewModel>();
                          final route = MaterialPageRoute(builder: (context) => MoonScreen(deviceID: vm.deviceID));
                          await Navigator.push(context, route);
                        }
                      }
                    : null,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        transitionBuilder: (child, animation) => FadeTransition(opacity: animation, child: child),
                        child: Icon(iconData, size: 32, color: effectiveIconColor, key: ValueKey(iconData)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(title, style: theme.textTheme.titleMedium?.copyWith(color: effectiveFgColor)),
                            if (!isMoonActive)
                              Text(
                                subtitle,
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: effectiveFgColor,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              )
                            else
                              Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    getMoonPhaseName(moonStatus!.phaseAngle),
                                    style: theme.textTheme.bodySmall?.copyWith(color: effectiveFgColor),
                                    softWrap: false,
                                  ),
                                  Text(
                                    '${moonStatus!.illumination.toStringAsFixed(0)}%',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: effectiveFgColor,
                                      fontFeatures: [FontFeature.tabularFigures()],
                                    ),
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
