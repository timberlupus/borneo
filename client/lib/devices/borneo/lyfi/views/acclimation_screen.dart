import 'package:borneo_app/devices/borneo/lyfi/view_models/acclimation_view_model.dart';
import 'package:borneo_app/devices/borneo/lyfi/view_models/lyfi_view_model.dart';
import 'package:borneo_app/services/device_manager.dart';
import 'package:borneo_kernel/drivers/borneo/lyfi/lyfi_driver.dart';
import 'package:event_bus/event_bus.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_xlider/flutter_xlider.dart';

import 'package:provider/provider.dart';

class AcclimationScreen extends StatelessWidget {
  final String deviceID;
  const AcclimationScreen({required this.deviceID, super.key});

  @override
  Widget build(BuildContext context) {
    final items = _buildSettingItems(context);
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(title: Text('Acclimation Mode')),
      body: ChangeNotifierProvider(
        create:
            (cb) =>
                AcclimationViewModel(deviceID, cb.read<DeviceManager>(), globalEventBus: cb.read<EventBus>()),
        builder: (context, child) {
          return ListView.separated(
            physics: ClampingScrollPhysics(),
            shrinkWrap: true,
            itemBuilder: (context, index) => items[index],
            itemCount: items.length,
            separatorBuilder: (context, index) => SizedBox(height: 1),
          );
        },
      ),
    );
  }

  List<Widget> _buildSettingItems(BuildContext context) {
    final tileColor = Theme.of(context).colorScheme.surfaceContainer;
    return <Widget>[
      ListTile(title: Text('SETTINGS', style: Theme.of(context).textTheme.titleSmall)),
      Consumer<AcclimationViewModel>(
        builder:
            (context, vm, _) => SwitchListTile(
              title: Text('Enabled'),
              value: vm.enabled,
              onChanged: !vm.isBusy && vm.isOnline ? vm.setEanbled : null, // TODO check power state
            ),
      ),

      Consumer<AcclimationViewModel>(
        builder:
            (context, vm, _) => ListTile(
              tileColor: tileColor,
              title: Text('Start date'),
              trailing: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                mainAxisSize: MainAxisSize.min,
                children: [Text("2222/2222/222"), SizedBox(width: 8), const CupertinoListTileChevron()],
              ),
              onTap: !vm.isBusy && vm.isOnline && vm.enabled ? () {} : null,
            ),
      ),
      Consumer<AcclimationViewModel>(
        builder:
            (context, vm, _) => ListTile(
              tileColor: tileColor,
              leading: Text("Duration"),
              title: FlutterSlider(
                values: [5, 100],
                min: 5,
                max: 100,
                disabled: !vm.enabled,
                rangeSlider: false,
                hatchMark: FlutterSliderHatchMark(),
              ),
              trailing: Text("30 days"),
            ),
      ),
      Consumer<AcclimationViewModel>(
        builder:
            (context, vm, _) => ListTile(
              tileColor: tileColor,
              leading: Text('Start percent'),
              title: FlutterSlider(
                values: [10],
                min: 10,
                max: 90,
                disabled: !vm.enabled,
                rangeSlider: false,
                hatchMark: FlutterSliderHatchMark(),
              ),
              trailing: Text("90%"),
            ),
      ),
      ListTile(title: Text('STATUS', style: Theme.of(context).textTheme.titleSmall)),
      ListTile(title: Text("Elapsed time"), trailing: Text("3.3 days")),
      ListTile(title: Text("Current percent"), trailing: Text("63%")),
    ];
  }
}
