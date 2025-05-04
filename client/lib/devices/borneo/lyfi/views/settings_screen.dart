import 'package:borneo_app/devices/borneo/lyfi/view_models/settings_view_model.dart';
import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:flutter/material.dart';

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

  List<Widget> _buildSettingItems(BuildContext context) {
    final rightChevron = Icon(Icons.chevron_right_outlined, color: Theme.of(context).hintColor);
    final tileColor = Theme.of(context).colorScheme.surfaceContainer;
    return <Widget>[
      ListTile(title: const Text('DEVICE INFORMATION')),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.info_outline),
        title: Text('Name'),
        subtitle: Text(vm.borneoInfo.name),
        trailing: rightChevron,
        onTap: () {},
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.factory_outlined),
        title: const Text('Manufacturer & Model'),
        trailing: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [Text(vm.borneoInfo.manufName), Text(vm.borneoInfo.modelName)],
        ),
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.numbers_outlined),
        title: Text('Serial number'),
        subtitle: Text(vm.borneoInfo.serno.substring(0, 12)),
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.info_outline),
        title: Text('Device address'),
        subtitle: Text(vm.address.toString()),
        trailing: _buildWifiRssiIcon(context),
      ),

      // Location
      Selector<SettingsViewModel, ({bool canUpdate, GeoLocation? location})>(
        selector: (_, vm) => (canUpdate: vm.canUpdateGeoLocation, location: vm.location),
        builder:
            (context, map, _) => ListTile(
              tileColor: tileColor,
              leading: const Icon(Icons.location_pin),
              title: Text('Location'),
              subtitle:
                  map.location != null
                      ? Text("(${vm.location!.lat.toStringAsFixed(3)}, ${vm.location!.lng.toStringAsFixed(3)})")
                      : Text('Unknown'),
              trailing: rightChevron,
              onTap: map.canUpdate ? vm.updateGeoLocation : null,
            ),
      ),

      ListTile(title: Text('DEVICE STATUS')),

      Selector<SettingsViewModel, ({bool canUpdate, String? tz, DateTime timestamp})>(
        selector: (_, vm) => (canUpdate: vm.canUpdateTimezone, tz: vm.timezone, timestamp: vm.borneoStatus.timestamp),
        builder:
            (context, map, _) => ListTile(
              tileColor: tileColor,
              leading: Icon(Icons.access_time_outlined),
              title: Text('Device time & time zone'),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text(map.timestamp.toString()), Text(map.tz ?? "Unknown time zone")],
              ),
              trailing: rightChevron,
              onTap: map.canUpdate ? vm.updateTimezone : null,
            ),
      ),
      ListTile(
        leading: Icon(Icons.settings_power_outlined),
        tileColor: tileColor,
        title: Text('Power status at startup'),
        trailing: Selector<SettingsViewModel, PowerBehavior>(
          selector: (context, vm) => vm.selectedPowerBehavior,
          builder:
              (context, selectedPowerBehavior, child) => DropdownButton<PowerBehavior>(
                value: vm.selectedPowerBehavior,
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
                onChanged: (PowerBehavior? newValue) {
                  vm.selectedPowerBehavior = newValue!;
                },
              ),
        ),

        /*
         Text(
            vm.borneoDeviceStatus?.shutdownTimestamp?.toString() ?? 'PowerOn'),
            */
        onTap: () {},
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.power_off),
        title: Text('Last shutdown'),
        trailing: Text(vm.borneoStatus.shutdownTimestamp?.toString() ?? 'N/A'),
        subtitle: Text("Reason code: ${vm.borneoStatus.shutdownReason}"),
      ),

      // LED Lighting settings
      ListTile(title: Text('LIGHTING')),

      Selector<SettingsViewModel, ({bool canUpdate, LedCorrectionMethod correctionMethod})>(
        selector: (_, vm) => (canUpdate: vm.canUpdateCorrectionMethod, correctionMethod: vm.correctionMethod),
        builder:
            (context, map, _) => ListTile(
              leading: Icon(Icons.settings_power_outlined),
              tileColor: tileColor,
              title: Text('Correction method'),
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
                          value: LedCorrectionMethod.cie1931,
                          child: Text("CIE1931", style: Theme.of(context).textTheme.bodySmall),
                        ),
                      ],
                      onChanged: (LedCorrectionMethod? newValue) async {
                        await vm.updateLedCorrectionMethod(newValue!);
                      },
                    ),
              ),
              onTap: () {},
            ),
      ),

      // Version & upgrade group
      ListTile(title: Text('VERSION & UPGRADE')),
      ListTile(
        leading: Icon(Icons.info_outline),
        tileColor: tileColor,
        title: Text('Hardware version'),
        trailing: Text(vm.borneoInfo.hwVer.toString()),
      ),
      ListTile(
        leading: Icon(Icons.info_outline),
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
        title: Row(
          children: [
            Icon(Icons.warning, size: 24, color: Theme.of(context).colorScheme.error,),
            SizedBox(width: 8),
            Text('DANGER ZONE', style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ),
      ),
      ListTile(
        leading: Icon(Icons.restore_outlined),
        tileColor: tileColor,
        title: Text('Restore to factory settings', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        subtitle: Text('Your device will lose all custom settings.'),
        trailing: rightChevron,
      ),
    ];
  }
}
