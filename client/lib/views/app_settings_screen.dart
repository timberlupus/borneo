import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/view_models/app_settings_view_model.dart';
import 'package:borneo_app/widgets/generic_settings_screen.dart';

class AppSettingsScreen extends StatelessWidget {
  const AppSettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (cb) => AppSettingsViewModel(),
      builder: (context, child) {
        final vm = context.read<AppSettingsViewModel>();
        return FutureBuilder(
          future: vm.isInitialized ? null : vm.initialize(),
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
          trailing: DropdownButton<ThemeMode>(
            items: [
              DropdownMenuItem<ThemeMode>(
                value: ThemeMode.system,
                child: Text(context.translate("System"), style: Theme.of(context).textTheme.bodySmall),
              ),
              DropdownMenuItem<ThemeMode>(
                value: ThemeMode.light,
                child: Text(context.translate("Light"), style: Theme.of(context).textTheme.bodySmall),
              ),
              DropdownMenuItem<ThemeMode>(
                value: ThemeMode.dark,
                child: Text(context.translate("Dark"), style: Theme.of(context).textTheme.bodySmall),
              ),
            ],
            onChanged: (value) {
              final vm = context.read<AppSettingsViewModel>();
              if (value != null && vm.themeMode != value) {
                vm.changeBrightness(value);
              }
            },
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
