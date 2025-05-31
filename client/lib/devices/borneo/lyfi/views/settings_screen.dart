import 'package:borneo_app/devices/borneo/lyfi/view_models/settings_view_model.dart';
import 'package:borneo_app/widgets/map_location_picker.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_coap_driver.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/models.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  final SettingsViewModel vm;
  const SettingsScreen(this.vm, {super.key});

  @override
  Widget build(BuildContext context) {
    final items = _buildSettingItems(context);
    return ChangeNotifierProvider.value(
      value: vm,
      builder:
          (context, child) => Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            appBar: AppBar(title: Text('Settings')),
            body: ListView.separated(
              shrinkWrap: true,
              itemBuilder: (context, index) => items[index],
              itemCount: items.length,
              separatorBuilder: (context, index) => SizedBox(height: 1),
            ),
          ),
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
      return Icon(Icons.wifi_off_outlined, color: Theme.of(bc).colorScheme.error);
    }
  }

  Future<void> _pickLocation(BuildContext context, SettingsViewModel vm) async {
    final route = MaterialPageRoute(
      builder:
          (context) => MapLocationPicker(
            initialLocation: vm.location != null ? LatLng(vm.location!.lat, vm.location!.lng) : null,
          ),
    );
    try {
      final selectedLocation = await Navigator.push(context, route);
      if (selectedLocation != null) {
        // Update the location in the view model
        vm.enqueueUIJob(() async => await vm.updateGeoLocation(selectedLocation!));
      }
    } finally {
      //TODO
    }
  }

  List<Widget> _buildSettingItems(BuildContext context) {
    const rightChevron = CupertinoListTileChevron();
    final tileColor = Theme.of(context).colorScheme.surfaceContainer;
    return <Widget>[
      ListTile(dense: true, title: Text('DEVICE INFORMATION', style: Theme.of(context).textTheme.titleSmall)),
      ListTile(
        dense: true,
        tileColor: tileColor,
        leading: Icon(Icons.info_outline),
        title: Text('Name'),
        subtitle: Text(vm.borneoInfo.name),
        trailing: rightChevron,
        onTap: () {},
      ),
      ListTile(
        dense: true,
        tileColor: tileColor,
        leading: Icon(Icons.factory_outlined),
        title: const Text('Manufacturer & Model'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text(vm.borneoInfo.manufName), Text(vm.borneoInfo.modelName)],
        ),
      ),
      ListTile(
        dense: true,
        tileColor: tileColor,
        leading: const Icon(Icons.numbers_outlined),
        title: Text('Serial number'),
        trailing: Text(vm.borneoInfo.serno.substring(0, 12)),
      ),
      ListTile(
        dense: true,
        tileColor: tileColor,
        leading: _buildWifiRssiIcon(context),
        title: Text('Device address'),
        trailing: Text(vm.address.toString()),
      ),

      ListTile(dense: true, title: Text('DEVICE STATUS', style: Theme.of(context).textTheme.titleSmall)),

      Selector<SettingsViewModel, ({bool canUpdate, String? tz, DateTime timestamp})>(
        selector: (_, vm) => (canUpdate: vm.canUpdateTimezone, tz: vm.timezone, timestamp: vm.borneoStatus.timestamp),
        builder:
            (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              leading: const Icon(Icons.access_time_outlined),
              title: Text('Device time & time zone'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(map.timestamp.toString()), Text(map.tz ?? "Unknown time zone")],
              ),
              trailing: rightChevron,
              onTap: map.canUpdate ? vm.updateTimezone : null,
            ),
      ),

      Selector<SettingsViewModel, ({bool canUpdate, PowerBehavior behavior})>(
        selector: (_, vm) => (canUpdate: vm.canUpdatePowerBehavior, behavior: vm.powerBehavior),
        builder:
            (context, map, _) => ListTile(
              dense: true,
              leading: const Icon(Icons.settings_power_outlined),
              tileColor: tileColor,
              title: Text('Power status at startup'),
              trailing: DropdownButton<PowerBehavior>(
                value: map.behavior,
                items: [
                  DropdownMenuItem<PowerBehavior>(
                    value: PowerBehavior.autoPowerOn,
                    child: Text("Keep on", style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<PowerBehavior>(
                    value: PowerBehavior.maintainPowerOff,
                    child: Text("Keep off", style: Theme.of(context).textTheme.bodySmall),
                  ),
                  DropdownMenuItem<PowerBehavior>(
                    value: PowerBehavior.lastPowerState,
                    child: Text("Maintain last", style: Theme.of(context).textTheme.bodySmall),
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
        title: Text('Last shutdown'),
        trailing: Text(vm.borneoStatus.shutdownTimestamp?.toString() ?? 'N/A'),
        subtitle: Text("Reason code: ${vm.borneoStatus.shutdownReason}"),
      ),

      // LED Lighting settings
      ListTile(dense: true, title: Text('LIGHTING', style: Theme.of(context).textTheme.titleSmall)),

      // Location
      Selector<SettingsViewModel, ({bool canUpdate, GeoLocation? location})>(
        selector: (_, vm) => (canUpdate: vm.canUpdateGeoLocation, location: vm.location),
        builder:
            (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              leading: const Icon(Icons.location_pin),
              title: Text('Location for sun & moon simulation'),
              subtitle:
                  map.location != null
                      ? Text("(${vm.location!.lat.toStringAsFixed(3)}, ${vm.location!.lng.toStringAsFixed(3)})")
                      : Text('Unknown'),
              trailing: rightChevron,
              onTap:
                  map.canUpdate
                      ? () async {
                        if (context.mounted) {
                          await _pickLocation(context, vm);
                        }
                      }
                      : null,
            ),
      ),

      // Curve
      Selector<SettingsViewModel, ({bool canUpdate, LedCorrectionMethod correctionMethod})>(
        selector: (_, vm) => (canUpdate: vm.canUpdateCorrectionMethod, correctionMethod: vm.correctionMethod),
        builder:
            (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text('Correction curve'),
              trailing: Selector<SettingsViewModel, LedCorrectionMethod>(
                selector: (context, map) => map.correctionMethod,
                builder:
                    (context, selectedPowerBehavior, child) => DropdownButton<LedCorrectionMethod>(
                      value: map.correctionMethod,
                      items: [
                        DropdownMenuItem<LedCorrectionMethod>(
                          value: LedCorrectionMethod.log,
                          child: Text("Logarithmic", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<LedCorrectionMethod>(
                          value: LedCorrectionMethod.linear,
                          child: Text("Linear", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<LedCorrectionMethod>(
                          value: LedCorrectionMethod.exp,
                          child: Text("Exponential", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<LedCorrectionMethod>(
                          value: LedCorrectionMethod.gamma,
                          child: Text("Gamma", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<LedCorrectionMethod>(
                          value: LedCorrectionMethod.cie1931,
                          child: Text("CIE1931", style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                      onChanged: (LedCorrectionMethod? newValue) async {
                        await vm.updateLedCorrectionMethod(newValue!);
                      },
                    ),
              ),
            ),
      ),

      Selector<SettingsViewModel, ({bool canUpdate, Duration duration})>(
        selector: (_, vm) => (canUpdate: vm.canUpdateTemporaryDuration, duration: vm.temporaryDuration),
        builder:
            (context, map, _) => ListTile(
              dense: true,
              tileColor: tileColor,
              title: Text('Temporary light on duration'),
              trailing: Selector<SettingsViewModel, Duration>(
                selector: (context, map) => map.temporaryDuration,
                builder:
                    (context, selectedPowerBehavior, child) => DropdownButton<Duration>(
                      value: map.duration,
                      items: [
                        DropdownMenuItem<Duration>(
                          value: Duration(minutes: 5),
                          child: Text("5 minutes", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<Duration>(
                          value: Duration(minutes: 10),
                          child: Text("10 minutes", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<Duration>(
                          value: Duration(minutes: 20),
                          child: Text("20 minutes", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<Duration>(
                          value: Duration(hours: 1),
                          child: Text("1 hour", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<Duration>(
                          value: Duration(hours: 2),
                          child: Text("2 hour", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<Duration>(
                          value: Duration(hours: 4),
                          child: Text("4 hour", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<Duration>(
                          value: Duration(hours: 8),
                          child: Text("8 hour", style: Theme.of(context).textTheme.bodySmall),
                        ),
                        DropdownMenuItem<Duration>(
                          value: Duration(hours: 12),
                          child: Text("12 hour", style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                      onChanged: (Duration? newValue) async {
                        await vm.updateTemporaryDuration(newValue!);
                      },
                    ),
              ),
            ),
      ),

      // Version & upgrade group
      ListTile(dense: true, title: Text('VERSION & UPGRADE', style: Theme.of(context).textTheme.titleSmall)),
      ListTile(
        dense: true,
        leading: const Icon(Icons.info_outline),
        tileColor: tileColor,
        title: Text('Hardware version'),
        trailing: Text(vm.borneoInfo.hwVer.toString()),
      ),
      ListTile(
        dense: true,
        leading: const Icon(Icons.info_outline),
        tileColor: tileColor,
        title: Text('Firmware version'),
        trailing: Text(vm.borneoInfo.fwVer.toString()),
      ),
      /*
      ListTile(
        leading: Icon(Icons.upgrade_outlined),
        tileColor: tileColor,
        title: Text('Upgrade device firmware'),
        subtitle: vm.isOnline
            ? Text(vm.borneoDeviceStatus?.timestamp.toString() ?? 'N/A')
            : null,
        trailing: rightChevron,
        onTap: () {},
      ),
      */
      ListTile(
        dense: true,
        title: Row(
          children: [
            Icon(Icons.warning, size: 24, color: Theme.of(context).colorScheme.error),
            SizedBox(width: 8),
            Text('DANGER ZONE', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      ListTile(
        dense: true,
        leading: Icon(Icons.restore_outlined),
        tileColor: tileColor,
        title: Text('Restore to factory settings', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        subtitle: Text('Your device will lose all custom settings.'),
        trailing: rightChevron,
      ),
    ];
  }
}
