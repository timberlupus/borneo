import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:logger/logger.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/features/settings/view_models/app_settings_view_model.dart';
import 'package:borneo_app/shared/widgets/generic_settings_screen.dart';
import 'package:borneo_app/app/app.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (cb) => AppSettingsViewModel(globalEventBus: cb.read<EventBus>(), logger: cb.read<Logger>()),
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
          leading: Icon(Icons.settings_brightness_outlined),
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
                return DropdownMenuItem(value: loc, child: Text(loc.languageCode == 'zh' ? '中文 (简体)' : 'English (US)'));
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
        ListTile(leading: Icon(Icons.star_outline), title: Text(context.translate('Rate in application store'))),
        ListTile(
          leading: Icon(Icons.settings_brightness_outlined),
          title: Text(context.translate('Report an issue on GitHub')),
        ),
      ],
    ),
  ];
}
