import 'package:borneo_app/core/services/clock.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/acclimation_view_model.dart';
import 'package:borneo_app/core/services/devices/device_manager.dart';
import 'package:borneo_app/core/services/app_notification_service.dart';
import 'package:borneo_app/shared/widgets/generic_bottom_sheet_picker.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:flutter_gettext/flutter_gettext/gettext_localizations.dart';
import 'package:intl/intl.dart';
import 'package:logger/logger.dart';
import 'package:flutter_settings_ui/flutter_settings_ui.dart';
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
              return Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                appBar: AppBar(
                  title: Text(context.translate('Acclimation')),
                  actions: [
                    Consumer<AcclimationViewModel>(
                      builder: (context, vm, _) => TextButton.icon(
                        onPressed: vm.canSubmit ? () => onSubmit(vm, context) : null,
                        icon: const Icon(Icons.check, size: 24),
                        label: Text(context.translate('Apply')),
                      ),
                    ),
                  ],
                ),
                body: _buildSettingsList(context),
              );
            }
          },
        );
      },
    );
  }

  SettingsList _buildSettingsList(BuildContext context) {
    // use watch to rebuild when values change
    final vm = context.watch<AcclimationViewModel>();

    return SettingsList(
      sections: [
        SettingsSection(
          title: Text(context.translate('SETTINGS')),
          tiles: [
            SettingsTile.switchTile(
              title: Text(context.translate('Enable acclimation')),
              initialValue: vm.enabled,
              onToggle: !vm.isBusy && vm.isOnline && vm.isOn ? vm.setEanbled : null,
            ),
            SettingsTile.navigation(
              title: Text(context.translate('Start date')),
              value: Builder(
                builder: (ctx) {
                  final locale = Localizations.localeOf(ctx).toString();
                  return Text(
                    vm.startTimestamp.toLocal().year < 2025
                        ? context.translate('Not set')
                        : DateFormat.yMd(locale).format(vm.startTimestamp.toLocal()),
                  );
                },
              ),
              onPressed: !vm.isBusy && vm.isOnline
                  ? (bc) async {
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
                    }
                  : null,
            ),
            SettingsTile.navigation(
              title: Text(context.translate('Duration')),
              value: Text('${vm.days.round().toString()} ${context.translate('days')}'),
              onPressed: !vm.isBusy && vm.isOnline
                  ? (bc) async {
                      final options = [5, 7, 15, 30, 60, 100].map((e) => e.toDouble()).toList();
                      final current = options.contains(vm.days) ? vm.days : options.first;
                      await GenericBottomSheetPicker.show<double>(
                        context: context,
                        title: context.translate('Select Duration'),
                        entries: options
                            .map(
                              (d) => GenericBottomSheetPickerEntry(
                                value: d,
                                label: '${d.round()} ${context.translate('days')}',
                              ),
                            )
                            .toList(),
                        selectedValue: current,
                        onValueSelected: (val) => vm.updateDays(val),
                      );
                    }
                  : null,
            ),
            SettingsTile.navigation(
              title: Text(context.translate('Start strength')),
              value: Text('${vm.startPercent.round().toString()}%'),
              onPressed: !vm.isBusy && vm.isOnline
                  ? (bc) async {
                      final options = [10, 20, 30, 40, 50, 60, 70, 80, 90].map((e) => e.toDouble()).toList();
                      final current = options.contains(vm.startPercent) ? vm.startPercent : options.first;
                      await GenericBottomSheetPicker.show<double>(
                        context: context,
                        title: context.translate('Select Start strength'),
                        entries: options
                            .map((p) => GenericBottomSheetPickerEntry(value: p, label: '${p.round()}%'))
                            .toList(),
                        selectedValue: current,
                        onValueSelected: (val) => vm.updateStartPercent(val),
                      );
                    }
                  : null,
            ),
          ],
        ),
      ],
    );
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
