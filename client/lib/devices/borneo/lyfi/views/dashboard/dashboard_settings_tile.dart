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
        final iconColor = isDisabled ? theme.colorScheme.primary.withValues(alpha: 0.38) : theme.colorScheme.primary;
        final textColor = isDisabled ? theme.colorScheme.primary.withValues(alpha: 0.38) : theme.colorScheme.primary;
        return AspectRatio(
          aspectRatio: 1,
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
                        final vm = await lyfi.loadSettings(GettextLocalizations.of(context));
                        final route = MaterialPageRoute(builder: (context) => SettingsScreen(vm));
                        if (context.mounted) {
                          Navigator.push(context, route);
                        }
                      },
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final iconSize = constraints.maxHeight * 0.3;
                    return Column(
                      children: [
                        Expanded(
                          child: Center(
                            child: Icon(Icons.settings, size: iconSize, color: iconColor),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 12),
                          child: Text(
                            context.translate("Settings"),
                            style: theme.textTheme.titleMedium?.copyWith(color: textColor),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
