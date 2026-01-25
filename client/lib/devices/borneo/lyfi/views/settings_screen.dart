import 'package:borneo_app/devices/borneo/lyfi/view_models/controller_settings_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/settings_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/views/controller_settings_screen.dart';
import 'package:borneo_app/shared/widgets/bottom_sheet_picker.dart';
import 'package:borneo_app/shared/widgets/generic_settings_screen.dart';
import 'package:borneo_app/shared/widgets/map_location_picker.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter_gettext/flutter_gettext/context_ext.dart';
import 'package:logger/logger.dart';

import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsViewModel vm;
  const SettingsScreen(this.vm, {super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: vm,
      builder: (context, child) => GenericSettingsScreen(children: _buildSettingGroups(context)),
    );
  }

  Icon _buildWifiRssiIcon(BuildContext bc) {
    var rssi = vm.borneoStatus.wifiRssi;
    if (rssi != null) {
      return switch (RssiLevelExtension.fromRssi(rssi)) {
        RssiLevel.strong => Icon(Icons.wifi),
        RssiLevel.medium => Icon(Icons.wifi_2_bar),
        RssiLevel.weak => Icon(Icons.wifi_1_bar),
      };
    } else {
      return Icon(Icons.link_off, color: Theme.of(bc).colorScheme.error);
    }
  }

  Future<void> _pickLocation(BuildContext context, SettingsViewModel vm) async {
    // Build the route with the existing device location if available
    final LatLng? initialLocation = vm.location != null ? LatLng(vm.location!.lat, vm.location!.lng) : null;

    final route = MaterialPageRoute<LatLng?>(
      builder: (context) => MapLocationPicker(initialLocation: initialLocation),
      fullscreenDialog: true,
    );

    try {
      // Navigate to the picker and await a LatLng (null if cancelled)
      final LatLng? selectedLocation = await Navigator.of(context).push<LatLng?>(route);

      if (!context.mounted) {
        return;
      }

      if (selectedLocation != null) {
        await vm.updateGeoLocation(selectedLocation);
      }
    } catch (e, stackTrace) {
      if (context.mounted) {
        final log = context.read<Logger>();
        log.e("Failed select location", error: e, stackTrace: stackTrace);
      }
    }
  }

  List<Widget> _buildSettingGroups(BuildContext context) {
    const rightChevron = CupertinoListTileChevron();
    final tileColor = Theme.of(context).colorScheme.surfaceContainerHighest;
    return <Widget>[
      GenericSettingsGroup(
        title: context.translate('DEVICE INFORMATION'),
        children: [
          ListTile(
            dense: true,
            tileColor: tileColor,
            leading: Icon(Icons.info_outline),
            title: Text(context.translate('Name')),
            subtitle: Text(vm.borneoInfo.name),
            trailing: rightChevron,
            onTap: () {},
          ),
          ListTile(
            dense: true,
            tileColor: tileColor,
            leading: Icon(Icons.info_outline),
            title: Text(context.translate('Manufacturer & Model')),
            trailing: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [Text(vm.borneoInfo.manufName), Text(vm.borneoInfo.modelName)],
            ),
          ),
          ListTile(
            dense: true,
            tileColor: tileColor,
            leading: const Icon(Icons.numbers_outlined),
            title: Text(context.translate('Serial number')),
            trailing: Text(vm.borneoInfo.serno.substring(0, 12)),
          ),
          ListTile(
            dense: true,
            tileColor: tileColor,
            leading: _buildWifiRssiIcon(context),
            title: Text(context.translate('Device address')),
            trailing: Text(vm.address.toString()),
          ),
          if (vm.isControllerSettingsAvailable)
            ListTile(
              dense: true,
              tileColor: tileColor,
              leading: const Icon(Icons.factory_outlined),
              title: Text(context.translate('Controller Settings')),
              trailing: rightChevron,
              onTap: () => _goControllerSettings(context, vm),
            ),
        ],
      ),
      GenericSettingsGroup(
        title: context.translate('DEVICE STATUS'),
        children: [
          Selector<SettingsViewModel, ({bool canUpdate, String? tz, DateTime timestamp})>(
            selector: (_, vm) =>
                (canUpdate: vm.canUpdateTimezone, tz: vm.timezone, timestamp: vm.borneoStatus.timestamp),
            builder: (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              leading: const Icon(Icons.access_time_outlined),
              title: Text(context.translate('Device time & time zone')),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(map.timestamp.toString()),
                  Text(map.tz != null ? map.tz! : context.translate('Unknown time zone')),
                ],
              ),
              trailing: rightChevron,
              onTap: map.canUpdate ? vm.updateTimezone : null,
            ),
          ),
          Selector<SettingsViewModel, ({bool canUpdate, PowerBehavior behavior})>(
            selector: (_, vm) => (canUpdate: vm.canUpdatePowerBehavior, behavior: vm.powerBehavior),
            builder: (context, map, _) => ListTile(
              dense: true,
              leading: const Icon(Icons.settings_power_outlined),
              tileColor: tileColor,
              title: Text(context.translate('Power status at startup')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatPowerBehavior(context, map.behavior)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: map.canUpdate ? () => _showPowerBehaviorPicker(context, vm) : null,
            ),
          ),
          ListTile(
            dense: true,
            tileColor: tileColor,
            leading: const Icon(Icons.power_off),
            title: Text(context.translate('Last shutdown')),
            trailing: Text(vm.borneoStatus.shutdownTimestamp?.toString() ?? context.translate('N/A')),
            subtitle: Text(
              context.translate("Reason code: {reasonCode}", nArgs: {"reasonCode": vm.borneoStatus.shutdownReason}),
            ),
          ),
        ],
      ),
      GenericSettingsGroup(
        title: context.translate('LIGHTING'),
        children: [
          Selector<SettingsViewModel, ({bool canUpdate, GeoLocation? location})>(
            selector: (_, vm) => (canUpdate: vm.canUpdateGeoLocation, location: vm.location),
            builder: (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              leading: const Icon(Icons.location_pin),
              title: Text(context.translate('Location for sun & moon simulation')),
              subtitle: map.location != null
                  ? Text("(${vm.location!.lat.toStringAsFixed(3)}, ${vm.location!.lng.toStringAsFixed(3)})")
                  : Text(context.translate('Unknown')),
              trailing: rightChevron,
              onTap: map.canUpdate
                  ? () async {
                      if (context.mounted) {
                        await _pickLocation(context, vm);
                      }
                    }
                  : null,
            ),
          ),
          Selector<SettingsViewModel, ({bool canUpdate, LedCorrectionMethod correctionMethod})>(
            selector: (_, vm) => (canUpdate: vm.canUpdateCorrectionMethod, correctionMethod: vm.correctionMethod),
            builder: (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(context.translate('Correction curve')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatCorrectionMethod(context, map.correctionMethod)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: map.canUpdate ? () => _showCorrectionMethodPicker(context, vm) : null,
            ),
          ),
          Selector<SettingsViewModel, ({bool canUpdate, Duration duration})>(
            selector: (_, vm) => (canUpdate: vm.canUpdateTemporaryDuration, duration: vm.temporaryDuration),
            builder: (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(context.translate('Temporary light on duration')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatDuration(context, map.duration)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: map.canUpdate ? () => _showTemporaryDurationPicker(context, vm) : null,
            ),
          ),
          Selector<SettingsViewModel, ({bool canUpdate, bool cloudEnabled})>(
            selector: (_, vm) => (canUpdate: vm.canUpdateCloudEnabled, cloudEnabled: vm.cloudEnabled),
            builder: (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(context.translate('Cloud simulation')),
              subtitle: Text(context.translate('Simulate cloud shadow effect')),
              trailing: Switch(
                value: map.cloudEnabled,
                onChanged: map.canUpdate
                    ? (bool value) async {
                        await vm.updateCloudEnabled(value);
                      }
                    : null,
              ),
            ),
          ),
        ],
      ),

      GenericSettingsGroup(
        title: context.translate('THERMAL MANAGEMENT'),
        children: [
          Selector<SettingsViewModel, ({bool canUpdate, FanMode fanMode})>(
            selector: (_, vm) => (canUpdate: vm.canUpdateFanMode, fanMode: vm.fanMode),
            builder: (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(context.translate('Fan mode')),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_formatFanMode(context, map.fanMode)),
                  const SizedBox(width: 8),
                  const Icon(Icons.chevron_right),
                ],
              ),
              onTap: map.canUpdate ? () => _showFanModePicker(context, vm) : null,
            ),
          ),
          Selector<SettingsViewModel, ({bool canUpdate, int manualFanPower, FanMode fanMode})>(
            selector: (_, vm) =>
                (canUpdate: vm.canUpdateManualFanPower, manualFanPower: vm.manualFanPower, fanMode: vm.fanMode),
            builder: (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(
                context.translate('Manual fan power'),
                style: map.fanMode == FanMode.manual
                    ? null
                    : TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38)),
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${map.manualFanPower}%',
                    style: map.fanMode == FanMode.manual
                        ? Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.primary)
                        : Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38),
                          ),
                  ),
                  SizedBox(width: 8),
                  rightChevron,
                ],
              ),
              onTap: map.canUpdate ? () => _showManualFanPowerDialog(context, vm, map.manualFanPower) : null,
            ),
          ),
        ],
      ),

      GenericSettingsGroup(
        title: context.translate('VERSION & UPGRADE'),
        children: [
          ListTile(
            dense: true,
            leading: const Icon(Icons.info_outline),
            tileColor: tileColor,
            title: Text(context.translate('Hardware version')),
            trailing: Text(vm.borneoInfo.hwVer.toString()),
          ),
          ListTile(
            dense: true,
            leading: const Icon(Icons.info_outline),
            tileColor: tileColor,
            title: Text(context.translate('Firmware version')),
            trailing: Text(vm.borneoInfo.fwVer.toString() + (vm.borneoInfo.isCE ? " (CE)" : " (PRO)")),
          ),
        ],
      ),
      GenericSettingsGroup(
        title: context.translate('DANGER ZONE'),
        children: [
          ListTile(
            dense: true,
            leading: Icon(Icons.restore_outlined),
            tileColor: tileColor,
            title: Text(
              context.translate('Restore to factory settings'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
            subtitle: Text(context.translate('Your device will lose all custom settings.')),
            trailing: rightChevron,
            onTap: () => _showFactoryResetDialog(context, vm),
          ),
        ],
      ),
    ];
  }

  void _goControllerSettings(BuildContext context, SettingsViewModel svm) {
    final csvm = ControllerSettingsViewModel(
      deviceID: svm.deviceID,
      deviceManager: svm.deviceManager,
      globalEventBus: svm.globalEventBus,
      notification: svm.notification,
    );
    final route = MaterialPageRoute(builder: (context) => ControllerSettingsScreen(csvm));
    Navigator.push(context, route);
  }

  void _showFactoryResetDialog(BuildContext context, SettingsViewModel vm) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.translate('Restore Factory Settings')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(context.translate('Are you sure you want to restore this device to factory settings?')),
            SizedBox(height: 16),
            Text(context.translate('This action will:'), style: Theme.of(context).textTheme.titleSmall),
            SizedBox(height: 8),
            Text(context.translate('• Delete all custom settings and configurations')),
            Text(context.translate('• Disconnect the device from your network')),
            Text(context.translate('• Reset all schedules and modes to defaults')),
            SizedBox(height: 8),
            Text(
              context.translate('The device will need to be reconfigured after this operation.'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.translate('Cancel'))),
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.errorContainer,
              foregroundColor: Theme.of(context).colorScheme.onErrorContainer,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              vm.factoryReset().then((_) {
                if (context.mounted) {
                  if (Navigator.of(context).canPop()) {
                    Navigator.of(context).pop();
                  }
                }
              });
            },
            child: Text(context.translate('Restore')),
          ),
        ],
      ),
    );
  }

  void _showManualFanPowerDialog(BuildContext context, SettingsViewModel vm, int currentValue) {
    double tempValue = currentValue.toDouble();
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: Text(context.translate('Set Manual Fan Power')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${tempValue.toInt()}%'),
              Slider(
                value: tempValue,
                min: 0,
                max: 100,
                divisions: 100,
                onChanged: (value) {
                  setState(() {
                    tempValue = value;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(context).pop(), child: Text(context.translate('Cancel'))),
            FilledButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await vm.updateManualFanPower(tempValue.toInt());
              },
              child: Text(context.translate('Set')),
            ),
          ],
        ),
      ),
    );
  }

  String _formatPowerBehavior(BuildContext context, PowerBehavior behavior) {
    return switch (behavior) {
      PowerBehavior.autoPowerOn => context.translate("Keep on"),
      PowerBehavior.maintainPowerOff => context.translate("Keep off"),
      PowerBehavior.lastPowerState => context.translate("Maintain last"),
    };
  }

  void _showPowerBehaviorPicker(BuildContext context, SettingsViewModel vm) {
    final options = [
      {'value': PowerBehavior.autoPowerOn, 'label': context.translate("Keep on")},
      {'value': PowerBehavior.maintainPowerOff, 'label': context.translate("Keep off")},
      {'value': PowerBehavior.lastPowerState, 'label': context.translate("Maintain last")},
    ];
    final currentIndex = options.indexWhere((option) => option['value'] == vm.powerBehavior);

    BottomSheetPicker.show(
      context: context,
      title: context.translate('Select power status'),
      items: options.map((option) => option['label'] as String).toList(),
      selectedIndex: currentIndex >= 0 ? currentIndex : 0,
      onItemSelected: (index) async {
        final selectedOption = options[index];
        await vm.updatePowerBehavior(selectedOption['value'] as PowerBehavior);
      },
    );
  }

  String _formatCorrectionMethod(BuildContext context, LedCorrectionMethod method) {
    return switch (method) {
      LedCorrectionMethod.log => context.translate("Logarithmic"),
      LedCorrectionMethod.linear => context.translate("Linear"),
      LedCorrectionMethod.exp => context.translate("Exponential"),
      LedCorrectionMethod.gamma => context.translate("Gamma"),
      LedCorrectionMethod.cie1931 => context.translate("CIE1931"),
    };
  }

  void _showCorrectionMethodPicker(BuildContext context, SettingsViewModel vm) {
    final options = [
      {'value': LedCorrectionMethod.log, 'label': context.translate("Logarithmic")},
      {'value': LedCorrectionMethod.linear, 'label': context.translate("Linear")},
      {'value': LedCorrectionMethod.exp, 'label': context.translate("Exponential")},
      {'value': LedCorrectionMethod.gamma, 'label': context.translate("Gamma")},
      {'value': LedCorrectionMethod.cie1931, 'label': context.translate("CIE1931")},
    ];
    final currentIndex = options.indexWhere((option) => option['value'] == vm.correctionMethod);

    BottomSheetPicker.show(
      context: context,
      title: context.translate('Select correction curve'),
      items: options.map((option) => option['label'] as String).toList(),
      selectedIndex: currentIndex >= 0 ? currentIndex : 0,
      onItemSelected: (index) async {
        final selectedOption = options[index];
        await vm.updateLedCorrectionMethod(selectedOption['value'] as LedCorrectionMethod);
      },
    );
  }

  String _formatDuration(BuildContext context, Duration duration) {
    if (duration.inMinutes == 5) return context.translate("5 minutes");
    if (duration.inMinutes == 10) return context.translate("10 minutes");
    if (duration.inMinutes == 20) return context.translate("20 minutes");
    if (duration.inHours == 1) return context.translate("1 hour");
    if (duration.inHours == 2) return context.translate("2 hours");
    if (duration.inHours == 4) return context.translate("4 hours");
    if (duration.inHours == 8) return context.translate("8 hours");
    if (duration.inHours == 12) return context.translate("12 hours");
    return duration.toString();
  }

  void _showTemporaryDurationPicker(BuildContext context, SettingsViewModel vm) {
    final options = [
      {'value': Duration(minutes: 5), 'label': context.translate("5 minutes")},
      {'value': Duration(minutes: 10), 'label': context.translate("10 minutes")},
      {'value': Duration(minutes: 20), 'label': context.translate("20 minutes")},
      {'value': Duration(hours: 1), 'label': context.translate("1 hour")},
      {'value': Duration(hours: 2), 'label': context.translate("2 hours")},
      {'value': Duration(hours: 4), 'label': context.translate("4 hours")},
      {'value': Duration(hours: 8), 'label': context.translate("8 hours")},
      {'value': Duration(hours: 12), 'label': context.translate("12 hours")},
    ];
    final currentIndex = options.indexWhere((option) => option['value'] == vm.temporaryDuration);

    BottomSheetPicker.show(
      context: context,
      title: context.translate('Select duration'),
      items: options.map((option) => option['label'] as String).toList(),
      selectedIndex: currentIndex >= 0 ? currentIndex : 0,
      onItemSelected: (index) async {
        final selectedOption = options[index];
        await vm.updateTemporaryDuration(selectedOption['value'] as Duration);
      },
    );
  }

  String _formatFanMode(BuildContext context, FanMode mode) {
    return switch (mode) {
      FanMode.pid => context.translate("PID Adaptive"),
      FanMode.manual => context.translate("Manual"),
    };
  }

  void _showFanModePicker(BuildContext context, SettingsViewModel vm) {
    final options = [
      {'value': FanMode.pid, 'label': context.translate("PID Adaptive")},
      {'value': FanMode.manual, 'label': context.translate("Manual")},
    ];
    final currentIndex = options.indexWhere((option) => option['value'] == vm.fanMode);

    BottomSheetPicker.show(
      context: context,
      title: context.translate('Select fan mode'),
      items: options.map((option) => option['label'] as String).toList(),
      selectedIndex: currentIndex >= 0 ? currentIndex : 0,
      onItemSelected: (index) async {
        final selectedOption = options[index];
        await vm.updateFanMode(selectedOption['value'] as FanMode);
      },
    );
  }
}
