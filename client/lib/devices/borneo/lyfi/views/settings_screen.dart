import 'package:borneo_common/io/net/rssi.dart';
import 'package:borneo_kernel/drivers/borneo/borneo_device_api.dart';
import 'package:flutter/material.dart';

import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:provider/provider.dart';

class SettingsScreen extends StatelessWidget {
  final LyfiViewModel vm;
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
    var rssi = vm.borneoDeviceStatus?.wifiRssi;
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
        subtitle: vm.isOnline ? Text(vm.borneoDeviceInfo.name) : null,
        trailing: rightChevron,
        onTap: () {},
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.factory_outlined),
        title: const Text('Manufacturer'),
        trailing: vm.isOnline ? Text(vm.borneoDeviceInfo.manufName) : null,
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.info_outline),
        title: const Text('Model'),
        trailing: vm.isOnline ? Text(vm.borneoDeviceInfo.modelName) : null,
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.numbers_outlined),
        title: Text('Serial number'),
        trailing: vm.isOnline ? Text(vm.borneoDeviceInfo.serno) : null,
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.info_outline),
        title: Text('Address'),
        subtitle: Text(vm.deviceEntity.address.toString()),
        trailing:
            vm.isOnline
                ? _buildWifiRssiIcon(context)
                : Icon(Icons.wifi_off_outlined, color: Theme.of(context).colorScheme.error),
      ),
      ListTile(title: Text('DEVICE STATUS')),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.access_time_outlined),
        title: Text('Device time'),
        subtitle: vm.isOnline ? Text(vm.borneoDeviceStatus?.timestamp.toString() ?? '') : null,
        trailing: rightChevron,
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.location_pin),
        title: Text('Time zone'),
        subtitle: vm.isOnline ? Text(vm.borneoDeviceStatus?.timezone ?? '') : null,
        trailing: rightChevron,
      ),
      ListTile(
        leading: Icon(Icons.settings_power_outlined),
        tileColor: tileColor,
        title: Text('Power status at startup'),
        trailing: DropdownButton<PowerBehavior>(
          items: [
            DropdownMenuItem<PowerBehavior>(
              value: PowerBehavior.autoPowerOn,
              child: Text("On", style: Theme.of(context).textTheme.bodySmall),
            ),
            DropdownMenuItem<PowerBehavior>(
              value: PowerBehavior.maintainPowerOff,
              child: Text("Off", style: Theme.of(context).textTheme.bodySmall),
            ),
            DropdownMenuItem<PowerBehavior>(
              value: PowerBehavior.lastPowerState,
              child: Text("Maintain last", style: Theme.of(context).textTheme.bodySmall),
            ),
          ],
          onChanged: (value) {},
        ),

        /*
         Text(
            vm.borneoDeviceStatus?.shutdownTimestamp?.toString() ?? 'PowerOn'),
            */
        onTap: () {},
      ),
      ListTile(
        tileColor: tileColor,
        leading: Icon(Icons.emergency_outlined),
        title: Text('Last emergency shutdown'),
        trailing: Text(vm.borneoDeviceStatus?.shutdownTimestamp?.toString() ?? 'N/A'),
        subtitle: Text("Reason: ${vm.borneoDeviceStatus?.shutdownReason}"),
      ),

      // Version & upgrade group
      ListTile(title: Text('VERSION & UPGRADE')),
      ListTile(
        leading: Icon(Icons.info_outline),
        tileColor: tileColor,
        title: Text('Hardware version'),
        trailing: vm.isOnline ? Text(vm.borneoDeviceInfo.hwVer.toString()) : null,
      ),
      ListTile(
        leading: Icon(Icons.info_outline),
        tileColor: tileColor,
        title: Text('Firmware version'),
        trailing: vm.isOnline ? Text(vm.borneoDeviceInfo.fwVer.toString()) : null,
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
      ListTile(title: Text('DANGER ZONE', style: TextStyle(color: Theme.of(context).colorScheme.error))),
      ListTile(
        leading: Icon(Icons.restore_outlined),
        tileColor: tileColor,
        title: Text('Restore to factory settings', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        subtitle: Text('Your device will lose all custom settings.'),
        trailing: Icon(Icons.warning),
      ),
    ];
  }
}
