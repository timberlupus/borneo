import 'package:borneo_app/core/services/local_service.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/core/services/url_launcher_service.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/settings/view_models/app_settings_view_model.dart';
import 'package:borneo_app/shared/widgets/generic_settings_screen.dart';
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
              return GenericSettingsScreen(title: context.translate("App Settings"), children: buildItems(context));
            }
          },
        );
      },
    );
  }

  List<Widget> buildItems(BuildContext context) => <Widget>[
    GenericSettingsGroup(
      title: context.translate('APPEARANCE'),
      children: [
        ListTile(
          leading: const Icon(Icons.settings_brightness_outlined),
          title: Text(context.translate('Theme')),
          trailing: Selector<AppSettingsViewModel, ThemeMode>(
            selector: (_, vm) => vm.themeMode,
            builder: (context, mode, _) => DropdownButton<ThemeMode>(
              value: mode,
              onChanged: (val) {
                if (val != null) context.read<AppSettingsViewModel>().changeBrightness(val);
              },
              items: [
                DropdownMenuItem(value: ThemeMode.system, child: Text(context.translate('System'))),
                DropdownMenuItem(value: ThemeMode.light, child: Text(context.translate('Light'))),
                DropdownMenuItem(value: ThemeMode.dark, child: Text(context.translate('Dark'))),
              ],
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.language_outlined),
          title: Text(context.translate('Language')),
          trailing: Selector<AppSettingsViewModel, Locale?>(
            selector: (_, vm) => vm.locale,
            builder: (context, locale, _) => DropdownButton<Locale>(
              value: locale ?? const Locale('en', 'US'),
              onChanged: (val) {
                if (val != null) context.read<AppSettingsViewModel>().changeLocale(val);
              },
              items: kSupportedLocales.map((loc) {
                return DropdownMenuItem(value: loc, child: Text(LanguageConfig.getLocaleDisplayName(loc)));
              }).toList(),
            ),
          ),
        ),
        ListTile(
          leading: Icon(Icons.thermostat_outlined),
          title: Text(context.translate('Temperature Unit')),
          trailing: Selector<AppSettingsViewModel, String>(
            selector: (_, vm) => vm.temperatureUnit,
            builder: (context, unit, _) => DropdownButton<String>(
              value: unit,
              onChanged: (val) {
                if (val != null) context.read<AppSettingsViewModel>().changeTemperatureUnit(val);
              },
              items: [
                DropdownMenuItem(value: 'C', child: Text(context.translate('℃ (Celsius)'))),
                DropdownMenuItem(value: 'F', child: Text(context.translate('℉ (Fahrenheit)'))),
              ],
            ),
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
          trailing: const CupertinoListTileChevron(),
        ),
        ListTile(
          leading: const Icon(Icons.settings_brightness_outlined),
          title: Text(context.translate('Report an issue on GitHub')),
          trailing: const CupertinoListTileChevron(),
          onTap: () => _openUrl(context, githubIssuesUrl),
        ),
      ],
    ),
  ];
}
