import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../view_models/lyfi_view_model.dart';
import 'dashboard_acclimation_tile.dart';
import 'dashboard_chart.dart';
import 'dashboard_power_switch_tile.dart';
import 'dashboard_temporary_tile.dart';
import 'dashboard_temperature_tile.dart';
import 'dashboard_fan_tile.dart';
import 'dashboard_power_tile.dart';
import 'dashboard_dimming_tile.dart';
import 'dashboard_settings_tile.dart';

class DashboardView extends StatelessWidget {
  const DashboardView({super.key});

  @override
  Widget build(BuildContext context) {
    final isOnline = context.read<LyfiViewModel>().isOnline;
    if (!isOnline) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: EdgeInsets.fromLTRB(0, 0, 0, 0),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Chart
            LayoutBuilder(
              builder:
                  (context, constraints) => AspectRatio(
                    aspectRatio: 2.75,
                    child: Container(
                      color: Theme.of(context).colorScheme.surfaceContainer,
                      margin: EdgeInsets.all(0),
                      child: const DashboardChart(),
                    ),
                  ),
            ),
            Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 0),
              child: Column(
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
