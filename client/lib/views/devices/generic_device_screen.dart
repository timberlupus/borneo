import 'package:borneo_app/services/devices/device_module_registry.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:borneo_app/models/devices/device_entity.dart';
import 'package:borneo_app/view_models/devices/base_device_view_model.dart';

class GenericDeviceScreen<TDeviceViewModel extends BaseDeviceViewModel> extends StatelessWidget {
  const GenericDeviceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final device = ModalRoute.of(context)!.settings.arguments as DeviceEntity;
    final deviceModuleReg = context.read<IDeviceModuleRegistry>();
    final module = deviceModuleReg.metaModules[device.driverID]!;
    return ChangeNotifierProvider(
      create: (context) => module.detailsViewModelBuilder(context, device.id),
      builder: (context, child) {
        final vm = context.read<TDeviceViewModel>();
        return FutureBuilder(
          future: vm.initialize(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            } else {
              return module.detailsViewBuilder(context);
            }
          },
        );
      },
    );
  }
}
