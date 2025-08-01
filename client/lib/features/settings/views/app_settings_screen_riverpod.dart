import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/url_launcher_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart' as provider;

import '../providers/settings_providers.dart';
import '../../../shared/widgets/generic_settings_screen.dart';

class AppSettingsScreenRiverpod extends ConsumerWidget {
  const AppSettingsScreenRiverpod({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settingsState = ref.watch(settingsNotifierProvider);
    final settingsNotifier = ref.read(settingsNotifierProvider.notifier);

    if (settingsState.isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return GenericSettingsScreen(
      title: context.translate("App Settings"),
      children: _buildItems(context, ref, settingsState, settingsNotifier),
    );
  }

  List<Widget> _buildItems(BuildContext context, WidgetRef ref, dynamic settingsState, dynamic settingsNotifier) {
    return [
      GenericSettingsGroup(
        title: context.translate('APPEARANCE'),
        children: [
          ListTile(
            leading: const Icon(Icons.settings_brightness_outlined),
            title: Text(context.translate('Theme')),
            trailing: DropdownButton<ThemeMode>(
              value: settingsState.themeMode,
              onChanged: (mode) {
                if (mode != null) {
                  settingsNotifier.changeBrightness(mode);
                }
              },
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(context.translate('System'))),
                DropdownMenuItem(value: ThemeMode.light, child: Text(context.translate('Light'))),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(context.translate('Dark'))),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.language_outlined),
            title: Text(context.translate('Language')),
            trailing: DropdownButton<Locale>(
              value: settingsState.locale ?? const Locale('en', 'US'),
              onChanged: (locale) {
                if (locale != null) {
                  settingsNotifier.changeLocale(locale);
                }
              },
              items: [
                const DropdownMenuItem(value: Locale('en', 'US'), child: Text('English (US)')),
                const DropdownMenuItem(value: Locale('zh', 'CN'), child: Text('中文 (简体)')),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.thermostat_outlined),
            title: Text(context.translate('Temperature Unit')),
            trailing: DropdownButton<String>(
              value: settingsState.temperatureUnit,
              onChanged: (unit) {
                if (unit != null) {
                  settingsNotifier.changeTemperatureUnit(unit);
                }
              },
              items: [
                const DropdownMenuItem(value: 'C', child: Text('℃ (Celsius)')),
                const DropdownMenuItem(value: 'F', child: Text('℉ (Fahrenheit)')),
              ],
            ),
          ),
        ],
      ),
      GenericSettingsGroup(
        title: context.translate('FEEDBACK'),
        children: [
          ListTile(
            leading: const Icon(Icons.star_outline),
            title: Text(context.translate('Rate in application store')),
            onTap: () {
              // TODO
            },
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_outlined),
            title: Text(context.translate('Report an issue on GitHub')),
            onTap: () async {
              final urlLauncher = UrlLauncherService(
                notification: provider.Provider.of<IAppNotificationService>(context, listen: false),
              );
              await urlLauncher.open('https://github.com/borneo-iot/borneo/issues');
            },
          ),
        ],
      ),
    ];
  }
}
