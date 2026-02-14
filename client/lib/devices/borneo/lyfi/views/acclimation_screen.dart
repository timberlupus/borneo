import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/acclimation_view_model.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';

import 'package:provider/provider.dart';

class AcclimationScreen extends StatelessWidget {
  final String deviceID;
  const AcclimationScreen({required this.deviceID, super.key});

  @override
  Widget build(BuildContext context) {
    final vm = AcclimationViewModel(
      deviceManager: context.read<IDeviceManager>(),
      globalEventBus: context.read<EventBus>(),
      notification: context.read<IAppNotificationService>(),
      wotThing: context.read<IDeviceManager>().getWotThing(deviceID),
      gt: context.read<GettextLocalizations>(),
      logger: context.read<Logger>(),
    );
    return ChangeNotifierProvider(
      create: (cb) => vm,
      builder: (context, child) {
        return FutureBuilder(
          future: vm.initFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Scaffold(
                appBar: AppBar(title: Text(context.translate('Acclimation'))),
                body: Center(child: CircularProgressIndicator()),
              );
            } else if (snapshot.hasError) {
              return Scaffold(
                appBar: AppBar(title: Text(context.translate('Acclimation'))),
                body: Center(child: Text('Error: ${snapshot.error}')),
              );
            } else {
              final items = _buildSettingItems(context);
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: AppBar(
                  title: Text(context.translate('Acclimation')),
                  actions: [
                    Consumer<AcclimationViewModel>(
                      builder: (context, vm, _) => Switch(
                        value: vm.enabled,
                        onChanged: !vm.isBusy && vm.isOnline && vm.isOn ? vm.setEanbled : null,
                      ),
                    ),
                    Consumer<AcclimationViewModel>(
                      builder: (context, vm, _) => TextButton.icon(
                        onPressed: vm.canSubmit ? () => onSubmit(vm, context) : null,
                        icon: const Icon(Icons.check, size: 24),
                        label: Text(context.translate('Apply')),
                      ),
                    ),
                  ],
                ),
                body: SafeArea(
                  child: Column(
                    mainAxisSize: MainAxisSize.max,
                    children: [
                      Expanded(
                        child: ListView.separated(
                          physics: ClampingScrollPhysics(),
                          itemBuilder: (context, index) => items[index],
                          itemCount: items.length,
                          separatorBuilder: (context, index) => SizedBox(height: 1),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }
          },
        );
      },
    );
  }

  List<Widget> _buildSettingItems(BuildContext context) {
    final tileColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return <Widget>[
      ListTile(title: Text(context.translate('SETTINGS'), style: Theme.of(context).textTheme.titleSmall)),

      Consumer<AcclimationViewModel>(
        builder: (context, vm, _) => ListTile(
          tileColor: tileColor,
          title: Text(context.translate('Start date')),
          trailing: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                vm.startTimestamp.toLocal().year < 2025 ? '-' : DateFormat.yMd().format(vm.startTimestamp.toLocal()),
              ),
              SizedBox(width: 8),
              const CupertinoListTileChevron(),
            ],
          ),
          onTap: !vm.isBusy && vm.isOnline
              ? () async {
                  final now = context.read<IClock>().now();
                  final picked = await showDatePicker(
                    context: context,
                    initialDate: vm.startTimestamp.toLocal().year < 2025 ? now : vm.startTimestamp.toLocal(),
                    firstDate: DateTime(2025, 1, 1),
                    lastDate: now.add(const Duration(days: 100)),
                  );
                  if (picked != null) {
                    vm.updateStartTimestamp(picked);
                  }
                  /*
                          firstDate: now,
                          lastDate: now.add(Duration(days: vm.days.round())),
                        );
                        dlg.show
                        */
                }
              : null,
        ),
      ),
      Consumer<AcclimationViewModel>(
        builder: (context, vm, _) => ListTile(
          tileColor: tileColor,
          leading: Text(context.translate("Duration")),
          title: Slider(value: vm.days, min: 5, max: 100, onChanged: vm.updateDays),
          trailing: Text(
            '${vm.days.round().toString()} days',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
      ),
      Consumer<AcclimationViewModel>(
        builder: (context, vm, _) => ListTile(
          tileColor: tileColor,
          leading: Text(context.translate('Start percent')),
          title: Slider(value: vm.startPercent, min: 10, max: 90, onChanged: vm.updateStartPercent),
          trailing: Text(
            '${vm.startPercent.round().toString()}%',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(fontFeatures: [FontFeature.tabularFigures()]),
          ),
        ),
      ),
      /*
      ListTile(title: Text('STATUS', style: Theme.of(context).textTheme.titleSmall)),
      ListTile(title: Text("Elapsed time"), trailing: Text("3.3 days")),
      ListTile(title: Text("Current percent"), trailing: Text("63%")),
      */
    ];
  }

  Future<void> onSubmit(AcclimationViewModel vm, BuildContext context) async {
    await vm.submitToDevice();
    if (context.mounted) {
      Provider.of<IAppNotificationService>(
        context,
        listen: false,
      ).showSuccess(context.translate('Update acclimation settings succeed.'));
      Navigator.of(context).pop();
    }
  }
}
