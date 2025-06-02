import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../settings_screen.dart';

class DashboardSettingsTile extends StatelessWidget {
  const DashboardSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        decoration: BoxDecoration(color: theme.colorScheme.surfaceContainer, borderRadius: BorderRadius.circular(16)),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () async {
            final lyfi = context.read<LyfiViewModel>();
            final vm = await lyfi.loadSettings();
            final route = MaterialPageRoute(builder: (context) => SettingsScreen(vm));
            if (context.mounted) {
              Navigator.push(context, route);
            }
          },
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.settings_outlined, size: 40, color: theme.colorScheme.primary),
                SizedBox(height: 8),
                Text('Settings', style: theme.textTheme.titleMedium?.copyWith(color: theme.colorScheme.primary)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
