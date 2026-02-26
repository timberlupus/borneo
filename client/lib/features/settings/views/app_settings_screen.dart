import 'package:borneo_app/core/services/local_service.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/url_launcher_service.dart';
import 'package:borneo_app/shared/widgets/generic_bottom_sheet_picker.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/settings/view_models/app_settings_view_model.dart';
import 'package:borneo_app/app/app.dart';
import 'package:borneo_app/core/config/language_config.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  static const String githubIssuesUrl = 'https://github.com/borneo-iot/borneo/issues';

  Future<void> _openUrl(BuildContext context, String url) async {
    final urlLauncher = UrlLauncherService(
      notification: Provider.of<IAppNotificationService>(context, listen: false),
      logger: Provider.of<Logger>(context, listen: false),
    );
    await urlLauncher.open(url);
  }

  @override
  Widget build(BuildContext context) {
    final gt = GettextLocalizations.of(context);
    return ChangeNotifierProvider(
      create: (cb) => AppSettingsViewModel(
        globalEventBus: cb.read<EventBus>(),
        localeService: cb.read<ILocaleService>(),
        gt: gt,
        logger: cb.read<Logger>(),
      ),
      builder: (context, child) {
        final vm = context.read<AppSettingsViewModel>();
        return FutureBuilder(
          future: vm.initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(body: Center(child: CircularProgressIndicator()));
            } else if (snapshot.hasError) {
              return Scaffold(body: Center(child: Text('Error: ${snapshot.error}')));
            } else {
              return Scaffold(
                appBar: AppBar(title: Text(context.translate('App Settings')), elevation: 1),
                body: buildItems(context),
              );
            }
          },
        );
      },
    );
  }

  SettingsList buildItems(BuildContext context) => SettingsList(
    sections: [
      SettingsSection(
        title: Text(context.translate('APPEARANCE')),
        tiles: [
          SettingsTile.navigation(
            leading: const Icon(Icons.settings_brightness_outlined),
            title: Text(context.translate('Theme')),
            trailing: Selector<AppSettingsViewModel, ThemeMode>(
              selector: (_, vm) => vm.themeMode,
              builder: (context, themeMode, _) => Text(switch (themeMode) {
                ThemeMode.system => context.translate('System'),
                ThemeMode.light => context.translate('Light'),
                ThemeMode.dark => context.translate('Dark'),
              }),
            ),
            onPressed: (context) async {
              await GenericBottomSheetPicker.show<ThemeMode>(
                context: context,
                title: context.translate('Select Theme'),
                entries: [
                  GenericBottomSheetPickerEntry(value: ThemeMode.system, label: context.translate('System')),
                  GenericBottomSheetPickerEntry(value: ThemeMode.light, label: context.translate('Light')),
                  GenericBottomSheetPickerEntry(value: ThemeMode.dark, label: context.translate('Dark')),
                ],
                selectedValue: context.read<AppSettingsViewModel>().themeMode,
                onValueSelected: (val) => context.read<AppSettingsViewModel>().changeBrightness(val),
              );
            },
          ),
          SettingsTile.navigation(
            leading: Icon(Icons.language_outlined),
            title: Text(context.translate('Language')),
            trailing: Selector<AppSettingsViewModel, Locale?>(
              selector: (_, vm) => vm.locale,
              builder: (context, locale, _) {
                final display = LanguageConfig.getLocaleDisplayName(locale ?? const Locale('en', 'US'));
                return Text(display);
              },
            ),
            onPressed: (context) async {
              final vm = context.read<AppSettingsViewModel>();
              final current = vm.locale ?? const Locale('en', 'US');
              await GenericBottomSheetPicker.show<Locale>(
                context: context,
                title: context.translate('Select Language'),
                entries: kSupportedLocales
                    .map(
                      (loc) =>
                          GenericBottomSheetPickerEntry(value: loc, label: LanguageConfig.getLocaleDisplayName(loc)),
                    )
                    .toList(),
                selectedValue: current,
                onValueSelected: (val) {
                  vm.changeLocale(val);
                },
              );
            },
          ),
          SettingsTile.navigation(
            leading: Icon(Icons.thermostat_outlined),
            title: Text(context.translate('Temperature Unit')),
            trailing: Selector<AppSettingsViewModel, String>(
              selector: (_, vm) => vm.temperatureUnit,
              builder: (context, unit, _) => Text(switch (unit) {
                'C' => context.translate('℃'),
                'F' => context.translate('℉'),
                _ => context.translate(''),
              }),
            ),
            onPressed: (context) async {
              final vm = context.read<AppSettingsViewModel>();
              await GenericBottomSheetPicker.show<String>(
                context: context,
                title: context.translate('Select Temperature Unit'),
                entries: [
                  GenericBottomSheetPickerEntry(value: 'C', label: context.translate('℃ (Celsius)')),
                  GenericBottomSheetPickerEntry(value: 'F', label: context.translate('℉ (Fahrenheit)')),
                ],
                selectedValue: vm.temperatureUnit,
                onValueSelected: (val) => vm.changeTemperatureUnit(val),
              );
            },
          ),
        ],
      ),

      SettingsSection(
        title: Text(context.translate('FEEDBACK')),
        tiles: [
          SettingsTile(
            leading: const Icon(Icons.star_outline),
            title: Text(context.translate('Rate in application store')),
            trailing: const CupertinoListTileChevron(),
          ),
          SettingsTile(
            leading: const Icon(Icons.settings_brightness_outlined),
            title: Text(context.translate('Report an issue on GitHub')),
            trailing: const CupertinoListTileChevron(),
            onPressed: (bc) => _openUrl(bc, githubIssuesUrl),
          ),
        ],
      ),
    ],
  );
}
