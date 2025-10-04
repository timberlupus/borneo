import 'package:borneo_app/devices/borneo/lyfi/view_models/settings_view_model.dart';
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
            leading: Icon(Icons.factory_outlined),
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
              trailing: DropdownButton<PowerBehavior>(
                value: map.behavior,
                items: [
                  DropdownMenuItem<PowerBehavior>(
                    value: PowerBehavior.autoPowerOn,
                    child: Text(context.translate("Keep on"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<PowerBehavior>(
                    value: PowerBehavior.maintainPowerOff,
                    child: Text(context.translate("Keep off"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<PowerBehavior>(
                    value: PowerBehavior.lastPowerState,
                    child: Text(context.translate("Maintain last"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
                onChanged: (PowerBehavior? newValue) async {
                  await vm.updatePowerBehavior(newValue!);
                },
              ),
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
              trailing: DropdownButton<LedCorrectionMethod>(
                value: map.correctionMethod,
                items: [
                  DropdownMenuItem<LedCorrectionMethod>(
                    value: LedCorrectionMethod.log,
                    child: Text(context.translate("Logarithmic"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<LedCorrectionMethod>(
                    value: LedCorrectionMethod.linear,
                    child: Text(context.translate("Linear"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<LedCorrectionMethod>(
                    value: LedCorrectionMethod.exp,
                    child: Text(context.translate("Exponential"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<LedCorrectionMethod>(
                    value: LedCorrectionMethod.gamma,
                    child: Text(context.translate("Gamma"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<LedCorrectionMethod>(
                    value: LedCorrectionMethod.cie1931,
                    child: Text(context.translate("CIE1931"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
                onChanged: (LedCorrectionMethod? newValue) async {
                  await vm.updateLedCorrectionMethod(newValue!);
                },
              ),
            ),
          ),
          Selector<SettingsViewModel, ({bool canUpdate, Duration duration})>(
            selector: (_, vm) => (canUpdate: vm.canUpdateTemporaryDuration, duration: vm.temporaryDuration),
            builder: (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text(context.translate('Temporary light on duration')),
              trailing: DropdownButton<Duration>(
                value: map.duration,
                items: [
                  DropdownMenuItem<Duration>(
                    value: Duration(minutes: 5),
                    child: Text(context.translate("5 minutes"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<Duration>(
                    value: Duration(minutes: 10),
                    child: Text(context.translate("10 minutes"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<Duration>(
                    value: Duration(minutes: 20),
                    child: Text(context.translate("20 minutes"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<Duration>(
                    value: Duration(hours: 1),
                    child: Text(context.translate("1 hour"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<Duration>(
                    value: Duration(hours: 2),
                    child: Text(context.translate("2 hours"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<Duration>(
                    value: Duration(hours: 4),
                    child: Text(context.translate("4 hours"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<Duration>(
                    value: Duration(hours: 8),
                    child: Text(context.translate("8 hours"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<Duration>(
                    value: Duration(hours: 12),
                    child: Text(context.translate("12 hours"), style: Theme.of(context).textTheme.bodySmall),
                  ),
                ],
                onChanged: (Duration? newValue) async {
                  await vm.updateTemporaryDuration(newValue!);
                },
              ),
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
            trailing: Text(vm.borneoInfo.fwVer.toString()),
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
}
