import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:provider/provider.dart';
import '../../view_models/lyfi_view_model.dart';
import '../settings_screen.dart';

class DashboardSettingsTile extends StatelessWidget {
  const DashboardSettingsTile({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Selector<LyfiViewModel, bool>(
      selector: (_, vm) => vm.canChangeSettings,
      builder: (context, canChangeSettings, _) {
        final isDisabled = !canChangeSettings;
        final Color fgColor = theme.colorScheme.onSurface;
        final double disabledAlpha = 0.38;
        final Color effectiveFgColor = isDisabled ? fgColor.withValues(alpha: disabledAlpha) : fgColor;
        final Color iconColor = theme.colorScheme.primary;
        final Color effectiveIconColor = isDisabled ? iconColor.withValues(alpha: disabledAlpha) : iconColor;
        final gt = GettextLocalizations.of(context);
        return AspectRatio(
          aspectRatio: 2,
          child: Container(
            decoration: BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: isDisabled
                    ? null
                    : () async {
                        final lyfi = context.read<LyfiViewModel>();
                        final vm = await lyfi.loadSettings(gt);
                        final route = MaterialPageRoute(builder: (context) => SettingsScreen(vm));
                        if (context.mounted) {
                          Navigator.push(context, route);
                        }
                      },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Icon(Icons.settings, size: 32, color: effectiveIconColor),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              context.translate("Settings"),
                              style: theme.textTheme.titleMedium?.copyWith(color: effectiveFgColor),
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
