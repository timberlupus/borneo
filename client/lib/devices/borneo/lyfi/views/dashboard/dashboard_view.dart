import 'package:flutter/material.dart';

import 'dashboard_acclimation_tile.dart';
import 'dashboard_chart.dart';
import 'dashboard_power_switch_tile.dart';
import 'dashboard_temporary_tile.dart';
import 'dashboard_temperature_tile.dart';
import 'dashboard_fan_tile.dart';
import 'dashboard_power_tile.dart';
import 'dashboard_dimming_tile.dart';
import 'dashboard_settings_tile.dart';
import 'package:borneo_app/shared/widgets/screen_top_rounded_container.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Padding(
      padding: EdgeInsets.zero,
      child: SingleChildScrollView(
        primary: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chart
            LayoutBuilder(
              builder: (context, constraints) => AspectRatio(
                aspectRatio: 2.75,
                child: Container(
                  color: theme.scaffoldBackgroundColor,
                  margin: const EdgeInsets.all(0),
                  child: const ClipRect(child: DashboardChart()),
                ),
              ),
            ),
            const SizedBox(height: 24),
            ScreenTopRoundedContainer(
              color: colorScheme.surfaceContainer,
              padding: const EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: const Column(
                children: [
                  Row(
                    children: [
                      Expanded(flex: 1, child: DashboardPowerSwitchTile()),
                      SizedBox(width: 16),
                      Expanded(flex: 1, child: DashboardTemporaryTile()),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: DashboardPowerTile()),
                      SizedBox(width: 16),
                      Expanded(child: DashboardTemperatureTile()),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: DashboardFanTile()),
                      SizedBox(width: 16),
                      Expanded(child: DashboardDimmingTile()),
                    ],
                  ),
                  SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(child: DashboardAcclimationTile()),
                      SizedBox(width: 16),
                      Expanded(child: DashboardSettingsTile()),
                    ],
                  ),
                  SizedBox(height: 24),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
